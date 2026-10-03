// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftUI
import UIKit
import PetCore
import PetRendering

@MainActor final class IOSPetModel: ObservableObject {
    @Published private(set) var state = PetState()
    @Published private(set) var catalog = PetCatalog()
    @Published private(set) var message = ""
    @Published private(set) var saveError = ""
    @Published private(set) var startupError: String?
    @Published private(set) var speechText = ""
    @Published private(set) var speechOpacity = 0.0
    @Published private(set) var active = false
    @Published var fontSize = 15.0
    @Published var fontFamily = ""
    @Published var opacity = 0.8
    @Published var revealInterval = 0.15
    @Published var holdMultiplier = 1.0
    @Published var automaticDialogue = true
    private(set) var scene: PetScene?
    private var engine: PetEngine?
    private var session: PetForegroundSession?
    private var store: PetSaveStore?
    private var dialogue: PetDialogue?
    private var timer: Timer?
    private var speech: PetSpeechPlayback?
    private var speechEffects: PetDialogueEffects?
    private var speechPrevious = 0.0
    private let clock: any PetClock
    private let defaults: UserDefaults
    private var lastAutomatic = true
    private var stageVisible = false
    let root: URL?
    var saveDirectory: URL? { store?.directory }
    var ready: Bool { engine != nil && scene != nil && startupError == nil }
    var canOperate: Bool { ready && active && saveError.isEmpty }
    var settings: PetSpeechSettings {
        PetSpeechSettings(fontFamily:fontFamily,fontSize:fontSize,opacity:opacity,revealInterval:revealInterval,holdMultiplier:holdMultiplier,automaticDialogue:automaticDialogue)
    }
    var font: Font {
        if let font=UIFont(name:fontFamily,size:fontSize) { return Font(font) }
        return .system(size:fontSize)
    }
    var activityFeedback: ActivityFeedback? { state.activity.map { ActivityFeedback(session:$0,activity:catalog.activity($0.activityID),mood:state.mood) } }
    var inventoryItems: [ItemDefinition] {
        state.inventory.keys.sorted().compactMap { state.inventoryDefinition($0,catalog:catalog) }
    }
    var unknownInventoryIDs: [String] {
        state.inventory.keys.sorted().filter { state.inventoryDefinition($0,catalog:catalog) == nil }
    }
    /// Test hosts must not start the ordinary sandbox model when XCTest mounts the app.
    static func application() -> IOSPetModel {
        #if DEBUG
        if ProcessInfo.processInfo.environment["IPET_TEST_HOST"] == "1" {
            let id="iPet-host-"+UUID().uuidString
            let defaults=UserDefaults(suiteName:id)!
            defaults.set(false,forKey:"speechAutomaticDialogue")
            return IOSPetModel(directory:FileManager.default.temporaryDirectory.appendingPathComponent(id),defaults:defaults)
        }
        #endif
        return IOSPetModel()
    }
    init(root:URL? = Bundle.main.url(forResource:"PetAssets",withExtension:nil),directory:URL? = nil,defaults:UserDefaults = .standard,clock:any PetClock=SystemPetClock()) {
        self.root=root;self.defaults=defaults;self.clock=clock
        do {
            guard let root else { throw NSError(domain:"iPet",code:1,userInfo:[NSLocalizedDescriptionKey:"应用缺少内置资源。请重新构建安装。"] ) }
            let catalog=try PetCatalog.load(from:root.appendingPathComponent("gameplay.json"))
            let manifest=try PetManifest.load(from:root)
            let dialogue=PetDialogue(catalog:try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json")),clock:clock)
            let directory=try directory ?? FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("iPet",isDirectory:true)
            let store=PetSaveStore(directory:directory)
            let loaded=try store.load() ?? PetState()
            let engine=PetEngine(state:loaded,clock:clock,catalog:catalog)
            try engine.configureItemPricing(enabled:true)
            self.engine=engine;self.catalog=engine.catalog;self.state=engine.state
            self.store=store;self.dialogue=dialogue;self.session=PetForegroundSession(engine:engine,clock:clock)
            self.scene=PetScene(manifest:manifest,assetRoot:root)
            self.message=store.recoveryMessage ?? "欢迎回家。点点角色，或选一项活动。"
            scene?.onActionFinished = { [weak self] _ in self?.syncBase(force:true) }
            scene?.onDiagnostic = { text in NSLog("iPet iOS resource: %@",text) }
            loadSettings();syncBase(force:true)
            NSLog("IPET_IOS_READY clips=%ld items=%ld movement=0",manifest.clips.count,catalog.items.count)
        } catch {
            startupError=error.localizedDescription
            engine=nil;scene=nil;session=nil
            NSLog("IPET_IOS_STARTUP_ERROR %@",error.localizedDescription)
        }
    }
    func setActive(_ value:Bool) {
        guard ready, value != active else { return }
        if value {
            active=true
            if saveError.isEmpty { session?.activate() }
            scene?.isPaused = !saveError.isEmpty;scene?.resetTiming()
            dialogue?.resetTiming();speechPrevious=clock.now
            timer=Timer.scheduledTimer(withTimeInterval:0.15,repeats:true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            if let timer { RunLoop.main.add(timer,forMode:.common) }
        } else {
            timer?.invalidate();timer=nil
            session?.deactivate();active=false;state=engine?.state ?? state
            closeSpeech();scene?.isPaused=true;scene?.resetTiming();save()
        }
    }
    func tick() {
        guard active,saveError.isEmpty,let engine else { return }
        let shouldSave=session?.tick() ?? false
        state=engine.state
        processEvents();syncBase()
        let now=clock.now,delta=now-speechPrevious;speechPrevious=now
        if speech != nil,delta.isFinite,delta>=0,delta<=30 {
            if speech?.advance(by:delta) == true,let effects=speechEffects {
                speechEffects=nil
                _ = engine.applyDialogue(effects);state=engine.state;processEvents();save()
            }
            speechText=speech?.displayedText ?? ""
            speechOpacity=(speech?.opacity ?? 0)/0.8*settings.opacity
            if speech?.phase == .finished { closeSpeech() }
        }
        if let entry=dialogue?.automatic(state:state,eligible:canOperate && stageVisible && automaticDialogue && speech == nil && scene?.requestedAction == .idle) {
            showSpeech(entry.rendered(state:state),effects:entry.effects,automatic:true)
        }
        if shouldSave,saveError.isEmpty { save() }
    }
    func touch(_ point:CGPoint) {
        guard canOperate,let scene,scene.isOpaque(at:point) else { return }
        if let region=scene.region(at:point) { interact(region == "head" ? .touchHead:.touchBody) }
    }
    func interact(_ command:PetCommand) {
        guard canOperate,let engine,let scene else { return }
        closeSpeech()
        let action=engine.send(command);state=engine.state;processEvents()
        if action == .eat { scene.setFoodImage(path:catalog.items.first { $0.graphID.lowercased() == "eat" }?.imagePath) }
        if action == .drink { scene.setFoodImage(path:catalog.items.first { $0.graphID.lowercased() == "drink" }?.imagePath) }
        if [.head,.body].contains(action) { scene.playTouch(action,mood:engine.presentationMood) }
        else { scene.play(action,mood:engine.presentationMood) }
        message=action == .sleep ? "正在休息。" : action == .idle ? "起床啦。" : "已经收到你的照顾。"
        save()
    }
    func perform(_ command:PetEconomyCommand) {
        guard canOperate,let engine else { return }
        let result=engine.perform(command);message=result.message
        guard result.accepted else { return }
        closeSpeech();state=engine.state;catalog=engine.catalog
        processEvents();syncBase();save()
    }
    private func processEvents() {
        guard let engine,let scene else { return }
        var stopped=false,used=false
        for event in engine.drainEvents() {
            switch event {
            case .itemUsed(let id):
                if let item=engine.lastUsedItem,item.id==id {
                    used=true;scene.setFoodImage(path:item.imagePath)
                    scene.play(item.graphID.lowercased() == "drink" ? .drink:item.graphID.lowercased() == "gift" ? .gift:.eat,mood:engine.presentationMood)
                }
            case .activityStopped(let id,_,let earned,let bonus):
                stopped=true
                message="\(catalog.activity(id)?.name ?? id)已结束，收益\(earned.formatted(.number.precision(.fractionLength(2))))，奖励\(bonus.formatted(.number.precision(.fractionLength(2))))。"
            case .growthChanged(let change): message=change.message(name:state.name)
            case .scheduleChanged(let text): message=text
            }
        }
        if stopped,!used { _ = scene.finishActivity() }
    }
    private func syncBase(force:Bool=false) {
        guard let engine,let scene else { return }
        let base=PetPresentation(state:engine.state,catalog:catalog)
        scene.setPlaybackMood(engine.presentationMood)
        if force { _ = scene.restoreBase(state:engine.state,catalog:catalog,force:true);return }
        guard !scene.isFinishingActivity,[.idle,.sleep,.activity].contains(scene.requestedAction) else { return }
        if base.action != scene.requestedAction || base.graphID != scene.requestedGraphID {
            _ = scene.restoreBase(state:engine.state,catalog:catalog)
        } else if base.action == .idle,scene.mood != engine.presentationMood {
            _ = scene.playMoodTransition(from:scene.mood,to:engine.presentationMood)
        }
    }
    func save() {
        guard ready,let store,let engine else { return }
        let wasBlocked = !saveError.isEmpty
        do {
            try store.save(engine.state);saveError=""
            if wasBlocked,active {
                session?.activate();scene?.isPaused=false;scene?.resetTiming()
                dialogue?.resetTiming();speechPrevious=clock.now
            }
        } catch {
            session?.deactivate();state=engine.state;closeSpeech();scene?.isPaused=true
            saveError="保存失败：\(error.localizedDescription)\n当前进度仍在内存中，养成与操作已暂停，请重试保存。"
        }
    }
    func chat() {
        guard canOperate,let entry=dialogue?.click(state:state,gameplay:catalog,hour:Calendar.current.component(.hour,from:Date())) else {
            if canOperate { message="稍等片刻，再来聊聊天吧。" };return
        }
        showSpeech(entry.rendered(state:state),effects:entry.effects)
    }
    func setStageVisible(_ value:Bool) {
        stageVisible=value
        if !value { closeSpeech() }
    }
    private func showSpeech(_ text:String,effects:PetDialogueEffects?=nil,automatic:Bool=false,animate:Bool=true) {
        closeSpeech()
        let begin:()->Void = { [weak self] in
            guard let self,self.canOperate else { return }
            guard !automatic || self.automaticDialogue else { self.closeSpeech();return }
            self.speech=PetSpeechPlayback(text:text,settings:self.settings)
            self.speechEffects=effects;self.speechPrevious=self.clock.now
            self.speechText=" ";self.speechOpacity=self.settings.opacity
        }
        if !animate || !stageVisible || scene?.playSpeech(mood:state.mood,onReady:begin) != true { begin() }
    }
    func closeSpeech() {
        speech=nil;speechEffects=nil;speechText="";speechOpacity=0
        scene?.discardSpeechStart();scene?.finishSpeech()
    }
    func showPreview() { guard canOperate else { return };showSpeech("你好，这是消息预览。👋\n字号和透明度即时生效，速度与停留时间从下一条消息生效。预览不会改变养成属性。",animate:false) }
    func updateSpeechSettings() {
        let value=settings
        fontFamily=value.fontFamily;fontSize=value.fontSize;opacity=value.opacity
        revealInterval=value.revealInterval;holdMultiplier=value.holdMultiplier;automaticDialogue=value.automaticDialogue
        defaults.set(fontFamily,forKey:"speechFontFamily");defaults.set(fontSize,forKey:"speechFontSize")
        defaults.set(opacity,forKey:"speechOpacity");defaults.set(revealInterval,forKey:"speechRevealInterval")
        defaults.set(holdMultiplier,forKey:"speechHoldMultiplier");defaults.set(automaticDialogue,forKey:"speechAutomaticDialogue")
        if lastAutomatic != automaticDialogue { dialogue?.resetTiming();lastAutomatic=automaticDialogue }
        if speech != nil { speechOpacity=(speech?.opacity ?? 0)/0.8*opacity }
    }
    func resetSpeechSettings() {
        fontFamily="";fontSize=15;opacity=0.8;revealInterval=0.15;holdMultiplier=1;automaticDialogue=true;updateSpeechSettings()
    }
    private func loadSettings() {
        func number(_ key:String,_ fallback:Double)->Double { defaults.object(forKey:key) == nil ? fallback:defaults.double(forKey:key) }
        let value=PetSpeechSettings(fontFamily:defaults.string(forKey:"speechFontFamily") ?? "",fontSize:number("speechFontSize",15),opacity:number("speechOpacity",0.8),revealInterval:number("speechRevealInterval",0.15),holdMultiplier:number("speechHoldMultiplier",1),automaticDialogue:defaults.object(forKey:"speechAutomaticDialogue") == nil || defaults.bool(forKey:"speechAutomaticDialogue"))
        fontFamily=UIFont(name:value.fontFamily,size:value.fontSize) == nil ? "":value.fontFamily
        fontSize=value.fontSize;opacity=value.opacity;revealInterval=value.revealInterval;holdMultiplier=value.holdMultiplier;automaticDialogue=value.automaticDialogue;lastAutomatic=automaticDialogue
    }
}
