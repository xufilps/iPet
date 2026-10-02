// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import Combine
import SpriteKit
import PetCore
import PetRendering

enum ControlPage: String, CaseIterable { case status="状态", activity="活动", shop="商店", inventory="背包", settings="设置", statistics="统计" }

@MainActor final class AppModel: ObservableObject {
    @Published var state = PetState()
    @Published var selectedPage = ControlPage.status
    private(set) var catalog = PetCatalog()
    private(set) var assetRoot: URL!
    private var lastUIRefresh = 0.0
    @Published var message = ""
    @Published var size = UserDefaults.standard.object(forKey: "petSize") as? Double ?? 280
    @Published var topMost=true
    @Published var passThrough=false
    @Published var opacity=1.0
    private var windowBehavior:PetWindowBehavior { PetWindowBehavior(topMost:topMost,passThrough:passThrough,opacity:opacity) }
    @Published var simulationEnabled=true
    @Published var fixedMood:PetMood = .normal
    var presentationMood:PetMood { engine?.presentationMood ?? state.mood }
    @Published var interactionCycle=200
    @Published var autoMove = UserDefaults.standard.object(forKey: "autoMove") as? Bool ?? true
    @Published var visible = true
    @Published var toolbarEnabled=false
    @Published private(set) var favoriteItems:Set<String>=[]
    @Published private(set) var inventoryUseProgress:String?
    private var inventoryUseTask:Task<Void,Never>?
    private(set) var engine: PetEngine!
    private(set) var store: PetSaveStore!
    private var writable = true
    private(set) var petScene: PetScene!
    private var petPanel: PetPanel!
    private var petView: PetView!
    private var statusItem: NSStatusItem!
    private var controls: NSWindow?
    private var timer: AnyCancellable?
    private var lastSave = 0.0
    private var lastTick: Double?
    private let moveCycles=PetMoveCycles()
    private var walkPlan:PetWalkPlan?
    private var climbPlan:PetClimbPlan?
    private var sideHidePlan:PetSideHidePlan?
    private var sideHideHovered=false
    private var climbLocated=false
    private var edgeScreen:CGRect?
    private var needsEdgeRecovery=false
    private var moveRandom=SeededPetRandom(seed:UInt64.random(in:0...UInt64.max))
    private let autonomy = PetAutonomy()
    private var dialogue:PetDialogue!
    private let speech=PetSpeechWindow()
    private var speechUntil=0.0
    private var toolbar:PetToolbarWindow?
    private var lastToolbarRefresh=0.0
    private var menuToolbar:NSMenuItem!
    private var suspended = false
    private var observers: [NSObjectProtocol] = []
    private var menuVisibility: NSMenuItem!
    private var manualTest: Bool { ProcessInfo.processInfo.environment["IPET_MANUAL_TEST"] == "1" }
    private var smokeMode: Bool { ProcessInfo.processInfo.environment["IPET_SMOKE_TEST"] == "1" }
    init() {
        // Preserve preferences when moving from the prototype bundle identifier.
        let defaults = UserDefaults.standard
        let legacy = defaults.persistentDomain(forName: "org.xufilps.VPetApple") ?? [:]
        for key in ["petSize", "autoMove", "petX", "petY"] where defaults.object(forKey: key) == nil {
            if !smokeMode, let value = legacy[key] { defaults.set(value, forKey: key) }
        }
        size = defaults.object(forKey: "petSize") as? Double ?? 280
        autoMove = defaults.object(forKey: "autoMove") as? Bool ?? true
        toolbarEnabled = !smokeMode && defaults.bool(forKey:"toolbarEnabled")
        favoriteItems = smokeMode ? []:Set(defaults.stringArray(forKey:"favoriteItems") ?? [])
        topMost=smokeMode ? true:(defaults.object(forKey:"topMost") as? Bool ?? true)
        passThrough = !smokeMode && defaults.bool(forKey:"passThrough")
        opacity=smokeMode ? 1:PetWindowBehavior(opacity:defaults.object(forKey:"opacity") as? Double ?? 1).opacity
        simulationEnabled=smokeMode ? true:(defaults.object(forKey:"simulationEnabled") as? Bool ?? true)
        fixedMood=smokeMode ? .normal:(PetMood(rawValue:defaults.string(forKey:"fixedMood") ?? "") ?? .normal)
        interactionCycle=smokeMode ? 200:min(1000,max(30,defaults.object(forKey:"interactionCycle") as? Int ?? 200))
    }
    func start() throws {
        autonomy.setInteractionCycle(interactionCycle)
        size = size.isFinite ? min(500, max(150, size)) : 280
        let base: URL
        if smokeMode {
            // Fixed, explicit fixture directory enables repeat-launch acceptance; production path is never used.
            if manualTest, let path=ProcessInfo.processInfo.environment["IPET_TEST_SAVE_DIRECTORY"], path.hasPrefix("/"), !path.isEmpty {
                base=URL(fileURLWithPath:path,isDirectory:true)
            } else { base = FileManager.default.temporaryDirectory.appendingPathComponent("iPet-smoke-\(ProcessInfo.processInfo.processIdentifier)") }
        }
        else { base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("VPetApple") }
        store = PetSaveStore(directory: base)
        do { state = try store.load() ?? PetState(); message = store.recoveryMessage ?? "" }
        catch { writable = false; message = "\(error.localizedDescription) 本次仅运行，存档写入已暂停。" }
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("PetAssets") else { throw PetSaveError.invalidDocument }
        assetRoot = root
        catalog = try PetCatalog.load(from: root.appendingPathComponent("gameplay.json"))
        engine = PetEngine(state: state, catalog: catalog)
        engine.configureSimulation(enabled:simulationEnabled,fixedMood:fixedMood)
        state=engine.state
        dialogue=PetDialogue(catalog:try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json")))
        petScene = PetScene(manifest: try PetManifest.load(from: root), assetRoot: root)
        petScene.play(state.resting ? .sleep : .idle, mood: presentationMood)
        petScene.onIdleCycle = { [weak self] in self?.autonomy.recordIdleCycle() }
        petScene.onDiagnostic = { text in NSLog("%@", text) }
        petScene.onPinchLoop = { [weak self] in
            guard let self,self.visible,!self.suspended,self.petView.isInteracting,!self.petView.isDragging else { return false }
            self.applyPinchEffects();return true
        }
        petScene.onMovementLoop = { [weak self] in self?.movementLoop() ?? false }
        petScene.onMovementCompleted = { [weak self] in
            guard let self,self.visible,!self.suspended,self.autoMove,!self.petView.isInteracting,
                  self.needsEdgeRecovery,let screen=self.edgeScreen else { return false }
            return self.beginSideHide(screen:screen)
        }
        petScene.onActionFinished = { [weak self] action in
            guard let self else { return }
            if [.walkLeft,.walkRight,.climb,.sideHide].contains(action) { self.cancelMovement();self.persistPosition() }
            self.restoreBaseAnimation()
        }
        petPanel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        petPanel.title = "iPet · 桌宠"
        petPanel.isOpaque = false; petPanel.backgroundColor = .clear; petPanel.hasShadow = false
        petPanel.level = .floating; petPanel.hidesOnDeactivate = false; petPanel.isReleasedWhenClosed = false
        petPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        petView = PetView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        petView.setAccessibilityLabel("萝莉斯桌宠")
        petView.allowsTransparency = true; petView.preferredFramesPerSecond = 30
        petView.autoresizingMask = [.width, .height]; petView.presentScene(petScene)
        petPanel.contentView = petView
        petView.onPanelRequested = { [weak self] in self?.showControls() }
        petView.onPressBegin = { [weak self] in self?.engine.recordInteraction();self?.autonomy.reset() }
        petView.canPinch = { [weak self] point in
            guard let self,self.sideHidePlan == nil else { return false }
            return self.petScene.canPinch(at:point,mood:self.engine.presentationMood)
        }
        petView.onPinchStart = { [weak self] in
            guard let self else { return }
            self.cancelMovement();self.autonomy.reset()
            self.engine.recordPinchStart();self.applyPinchEffects();self.petScene.play(.pinch,mood:self.engine.presentationMood)
            self.recordAcceptanceInput("pinch-start")
        }
        petView.onPressEnd = { [weak self] in
            guard let self else { return }
            if self.petScene.requestedAction == .pinch { self.petScene.finishAction() }
            else if self.petScene.requestedAction == .idle { self.restoreBaseAnimation() }
        }
        petView.canLift = { [weak self] point in
            guard let self else { return false }
            return self.petScene.canRaise(at:point,mood:self.engine.presentationMood)
        }
        petView.onTouch = { [weak self] region in
            self?.recordAcceptanceInput("touch:\(region ?? "panel")")
            if self?.recoverSideHide() == true { return }
            if region == "head" { self?.command(.touchHead) }
            else if region == "body" { self?.command(.touchBody) }
            else { self?.sayClick() }
        }
        petView.onDragStart = { [weak self] in
            guard let self else { return }
            self.toolbar?.hide()
            self.recordAcceptanceInput("drag-start")
            self.engine.recordInteraction(); self.autonomy.reset();
            self.cancelMovement(reposition:false); self.petScene.beginRaise(mood:self.engine.presentationMood)
        }
        petView.onDragMotion = { [weak self] distance in self?.petScene.updateRaiseMotion(distance:distance) }
        petView.onDragEnd = { [weak self] in
            guard let self else { return }
            self.needsEdgeRecovery=false;self.edgeScreen=nil
            if !self.beginSideHide() { self.petScene.finishRaise();self.clampPosition() };self.persistPosition()
            self.recordAcceptanceInput("drag-end")
        }
        if let x = UserDefaults.standard.object(forKey: "petX") as? Double, let y = UserDefaults.standard.object(forKey: "petY") as? Double {
            petPanel.setFrameOrigin(NSPoint(x: x, y: y)); clampPosition()
        } else { resetPosition() }
        petPanel.orderFrontRegardless()
        toolbar=PetToolbarWindow { [weak self] action in self?.toolbarAction(action) }
        applyWindowPreferences()
        refreshToolbar()
        updateTextureResolution()
        buildMenu()
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.suspend() } })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.resume() } })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.edgeScreen=nil;self?.cancelMovement();self?.clampPosition();self?.restoreBaseAnimation(force:true); self?.updateTextureResolution() } })
        lastSave = ProcessInfo.processInfo.systemUptime; autonomy.reset()
        timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.tick() }
        if !message.isEmpty { showControls() }
        if smokeMode && !manualTest { startSmokeTest() }
    }
    private func recordAcceptanceInput(_ event:String) {
        guard manualTest else { return }
        NSLog("IPET_INPUT event=%@ front=%@ key=%d x=%.1f y=%.1f",event,NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown",petPanel.isKeyWindow ? 1 : 0,petPanel.frame.minX,petPanel.frame.minY)
    }
    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐾"
        statusItem.button?.toolTip = "iPet 原生桌宠"
        let menu = NSMenu()
        func item(_ title: String, _ selector: Selector) -> NSMenuItem { let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self; return item }
        menu.addItem(item("状态与设置…", #selector(showControls)))
        menu.addItem(item("活动…", #selector(showActivities))); menu.addItem(item("商店…", #selector(showShop)))
        menu.addItem(item("背包…", #selector(showInventory)))
        menu.addItem(item("统计与历史…", #selector(showStatistics)))
        menu.addItem(item("聊一句", #selector(sayClick)))
        menuToolbar=item("随宠工具栏",#selector(toggleToolbar));menuToolbar.state=toolbarEnabled ? .on : .off;menu.addItem(menuToolbar)
        menu.addItem(item("休息 / 起床", #selector(rest)))
        menuVisibility = item("隐藏桌宠", #selector(toggleVisibility)); menu.addItem(menuVisibility)
        menu.addItem(item("恢复窗口默认设置", #selector(resetWindowPreferences)))
        menu.addItem(item("重置位置", #selector(resetPosition))); menu.addItem(.separator())
        menu.addItem(item("退出 iPet", #selector(quit))); statusItem.menu = menu
        let main = NSMenu(), appMenu = NSMenu()
        let preferences = item("状态与设置…", #selector(showControls)); preferences.keyEquivalent = ","
        let exit = item("退出 iPet", #selector(quit)); exit.keyEquivalent = "q"
        appMenu.addItem(preferences); appMenu.addItem(.separator()); appMenu.addItem(exit)
        let root = NSMenuItem(); root.submenu = appMenu; main.addItem(root)
        // NSTextField's command shortcuts use the standard menu responder chain.
        let edit = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("重做", "redo:", "Z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.addItem(NSMenuItem(title:title,action:Selector(action),keyEquivalent:key))
        }
        let editRoot=NSMenuItem(title:"编辑",action:nil,keyEquivalent:""); editRoot.submenu=edit; main.addItem(editRoot)
        NSApp.mainMenu = main
    }
    private func applyPinchEffects() {
        _ = engine.send(.touchPinch);state=engine.state;petScene.setPlaybackMood(presentationMood);autonomy.reset();consumeEvents();save()
    }
    func command(_ command: PetCommand) {
        petView.cancelInteraction()
        cancelMovement(); autonomy.reset()
        let action = engine.send(command); state = engine.state
        consumeEvents()
        if !petScene.isFinishingActivity || ![.idle,.sleep].contains(action) {
            if [.head,.body].contains(action) { petScene.playTouch(action,mood:presentationMood) }
            else { petScene.play(action,mood:presentationMood) }
        }
        save()
    }
    func perform(_ command: PetEconomyCommand) {
        guard inventoryUseTask == nil else { message="正在使用背包物品，请完成或取消后再操作。";return }
        let result = engine.perform(command)
        state = engine.state; message = result.message
        if result.accepted {
            petView.cancelInteraction()
            cancelMovement(); autonomy.reset()
            let usedItem = consumeEvents()
            if !usedItem { restoreBaseAnimation() }
            save()
        }
    }
    func useInventory(id:String,count:Int) {
        guard inventoryUseTask == nil,count>0,catalog.item(id) != nil else { return }
        guard writable else { message="存档写入已暂停，暂不能批量使用。";return }
        let total=min(count,engine.state.inventory[id,default:0])
        guard total>0 else { return }
        petView.cancelInteraction();cancelMovement();autonomy.reset()
        inventoryUseProgress="已使用 0 / \(total) 件"
        inventoryUseTask=Task { [weak self] in
            guard let self else { return }
            var used=0
            while used<total,!Task.isCancelled,!self.suspended {
                let result=self.engine.useItems(id:id,count:min(32,total-used))
                used+=result.used;self.state=self.engine.state
                _=self.consumeEvents()
                self.inventoryUseProgress="已使用 \(used) / \(total) 件"
                self.message=result.used == 0 ? result.message:"已使用 \(used) / \(total) 件。"
                guard self.save() else { break }
                if result.used == 0 { break }
                try? await Task.sleep(for:.milliseconds(10))
            }
            self.inventoryUseProgress=nil;self.inventoryUseTask=nil
        }
    }
    func cancelInventoryUse() {
        inventoryUseTask?.cancel()
        if inventoryUseTask != nil { message="已停止剩余使用，完成部分已保存。" }
    }
    func toggleFavorite(id:String) {
        if favoriteItems.contains(id) { favoriteItems.remove(id) } else { favoriteItems.insert(id) }
        if !smokeMode { UserDefaults.standard.set(favoriteItems.sorted(),forKey:"favoriteItems") }
    }
    func itemMultiplier(id: String) -> Double {
        guard let item=catalog.item(id) else { return 0 }
        return PetItemRules.multiplier(category:item.category,expiry:state.itemCooldowns[id],now:Date())
    }
    @discardableResult private func consumeEvents() -> Bool {
        var usedItem = false, stopped = false
        let events=engine.drainEvents()
        let lastUsed=events.compactMap { event -> String? in if case let .itemUsed(id)=event { return id };return nil }.last
        for event in events {
            switch event {
            case let .activityStopped(id, reason, earned, bonus):
                stopped = true
                let title=catalog.activity(id)?.name ?? id
                let unit=catalog.activity(id)?.kind == .work ? "金币" : "经验"
                let reasonText=reason == .completed ? "完成" : reason == .manual ? "结束" : "因状态不佳停止"
                message="\(title)\(reasonText)，已获\(earned.formatted(.number.precision(.fractionLength(2))))\(unit)，完成奖励\(bonus.formatted(.number.precision(.fractionLength(2))))。"
            case .itemUsed: break
            }
        }
        if let id=lastUsed {
                if let item=catalog.item(id) {
                    usedItem = true
                    petScene.setFoodImage(path:item.imagePath)
                    let action: PetAction = item.graphID.lowercased() == "drink" ? .drink : item.graphID.lowercased() == "gift" ? .gift : .eat
                    petScene.play(action,mood:engine.presentationMood)
                }
        }
        if stopped {
            state = engine.state
            if !usedItem && !petScene.finishActivity() { restoreBaseAnimation() }
            save()
        }
        return usedItem
    }
    private func restoreBaseAnimation(force: Bool = false) {
        guard petScene != nil, sideHidePlan == nil, petView?.isInteracting != true else { return }
        _ = petScene.restoreBase(state:engine.state,catalog:catalog,force:force,mood:presentationMood)
    }
    @objc private func showActivities() { selectedPage = .activity; showControls() }
    @objc private func showShop() { selectedPage = .shop; showControls() }
    @objc private func showStatistics() { selectedPage = .statistics;showControls() }
    @objc private func showInventory() { selectedPage = .inventory; showControls() }
    @objc func sayClick() {
        guard visible, !suspended else { message="请先显示桌宠，再聊一句。";return }
        guard let entry=dialogue.click(state:engine.state,gameplay:catalog,hour:Calendar.current.component(.hour,from:Date()),mood:presentationMood) else { return }
        let oldMood=engine.presentationMood
        guard engine.applyDialogue(entry.effects) else { message="本地文本效果不合法，未应用。";return }
        state=engine.state;autonomy.reset();consumeEvents();save()
        if oldMood != presentationMood {
            _ = petScene.playMoodTransition(from:oldMood,to:presentationMood)
        }
        petScene.setPlaybackMood(presentationMood)
        showSpeech(entry.rendered(state:state))
    }
    private func showSpeech(_ text:String) {
        guard visible, !suspended, let screen=companionScreen else { return }
        speech.show(text:text,petFrame:speechAnchor,screen:screen)
        speechUntil=ProcessInfo.processInfo.systemUptime+max(5,min(14,Double(text.count)*0.08))
    }
    private var companionScreen:CGRect? { (needsEdgeRecovery ? edgeScreen : nil) ?? petPanel?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame }
    private var speechAnchor:CGRect { toolbar?.visibleFrame.map { petPanel.frame.union($0) } ?? petPanel.frame }
    @objc func toggleToolbar() { toolbarEnabled.toggle();updateToolbarPreference() }
    func updateToolbarPreference() {
        if !smokeMode { UserDefaults.standard.set(toolbarEnabled,forKey:"toolbarEnabled") }
        menuToolbar?.state=toolbarEnabled ? .on : .off
        refreshToolbar()
    }
    private func refreshToolbar() {
        guard toolbarEnabled,visible,!suspended,petView?.isInteracting != true,let screen=companionScreen,engine != nil else { toolbar?.hide();return }
        toolbar?.update(state:engine.state,catalog:catalog,message:message,petFrame:petPanel.frame,screen:screen)
    }
    private func toolbarAction(_ action:ToolbarAction) {
        switch action {
        case .status: selectedPage = .status;showControls()
        case .activity: showActivities()
        case .shop: showShop()
        case .inventory: showInventory()
        case .rest: command(.toggleRest)
        case .talk: sayClick()
        case .pauseOrResume: perform(state.activity?.isPaused == true ? .resumeActivity : .pauseActivity)
        case .stop: perform(.stopActivity)
        case .close: toolbarEnabled=false;updateToolbarPreference()
        }
        refreshToolbar()
    }
    @objc private func feed() { command(.feed) }
    @objc private func water() { command(.water) }
    @objc private func rest() { command(.toggleRest) }
    @objc private func quit() { NSApp.terminate(nil) }
    private func tick() {
        guard !suspended else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - (lastTick ?? now), 0), 0.1); lastTick = now
        if speech.isVisible {
            if now>=speechUntil { speech.hide() }
            else if let screen=companionScreen { speech.updatePosition(petFrame:speechAnchor,screen:screen) }
        }
        let oldMood = engine.presentationMood
        engine.tick()
        petScene.setPlaybackMood(engine.presentationMood)
        consumeEvents()
        if now - lastUIRefresh >= 0.25 { state = engine.state; lastUIRefresh = now }
        if now-lastToolbarRefresh>=0.25 { refreshToolbar();lastToolbarRefresh=now }
        if oldMood != engine.presentationMood {
            _ = petScene.playMoodTransition(from:oldMood,to:engine.presentationMood)
        }
        if visible {
            petPanel.ignoresMouseEvents = windowBehavior.ignoresMouse(interacting:petView.isInteracting,opaque:petView.opaqueUnderMouse())
            if sideHidePlan != nil,!passThrough,!petView.isInteracting {
                let hovered=petPanel.frame.contains(NSEvent.mouseLocation)
                if hovered != sideHideHovered { sideHideHovered=hovered;petScene.setSideHideHovered(hovered) }
            }
            if let plan=walkPlan {
                if !autoMove || petView.isInteracting || !petScene.isMovementAnimation { endWalking() }
                else if petScene.currentPhase == .loop,let screen=edgeScreen {
                    if let frame=plan.advance(pet:petPanel.frame,screen:screen,seconds:delta) { petPanel.setFrame(frame,display:true) }
                    else {
                        if !moveCycles.triesCompatibility() || !chooseMovement(previous:.walk(plan)) { endWalking() }
                    }
                }
            }
            if let plan=climbPlan {
                if !autoMove || petView.isInteracting || !petScene.isMovementAnimation || engine.presentationMood == .ill { endWalking() }
                else if petScene.currentPhase == .loop,let screen=edgeScreen {
                    if !climbLocated { petPanel.setFrame(plan.located(pet:petPanel.frame,screen:screen),display:true);climbLocated=true }
                    if let frame=plan.advance(pet:petPanel.frame,screen:screen,seconds:delta) { petPanel.setFrame(frame,display:true) }
                    else if !moveCycles.triesCompatibility() || !chooseMovement(previous:.traversal(plan)) { endWalking() }
                }
            }
        }
        let eligible = !manualTest && PetAutonomy.canStart(state:engine.state,action:petScene.requestedAction,visible:visible,interacting:petView.isInteracting,finishing:petScene.isFinishingActivity)
        if let entry=dialogue.automatic(state:engine.state,eligible:eligible && !speech.isVisible,mood:presentationMood) { showSpeech(entry.rendered(state:engine.state)) }
        if let behavior = autonomy.poll(eligible:eligible,allowsMovement:autoMove,mood:engine.presentationMood) {
            switch behavior {
            case .walkLeft, .walkRight:
                _ = chooseMovement()
            case .fidget:
                _ = petScene.playRandomFidget(mood:engine.presentationMood)
            case .specialIdle:
                _ = petScene.playSpecialIdle(mood:engine.presentationMood)
            case .doze:
                petScene.playDoze(mood:engine.presentationMood)
            }
        }
        if now - lastSave >= 60 { save(); lastSave = now }
    }
    private func cancelMovement(reposition:Bool=true) {
        walkPlan=nil;climbPlan=nil;sideHidePlan=nil;sideHideHovered=false;climbLocated=false
        if reposition && needsEdgeRecovery { clampPosition();needsEdgeRecovery=false;edgeScreen=nil }
    }
    private func beginSideHide(screen pinnedScreen:CGRect?=nil) -> Bool {
        guard let screen=pinnedScreen ?? NSScreen.screens.max(by:{ intersectionArea($0.visibleFrame)<intersectionArea($1.visibleFrame) })?.visibleFrame,
              let plan=PetSideHidePlan.make(pet:petPanel.frame,screen:screen) else { return false }
        walkPlan=nil;climbPlan=nil;climbLocated=false;sideHidePlan=plan;sideHideHovered=false
        edgeScreen=screen;needsEdgeRecovery=true;autonomy.reset()
        petPanel.setFrame(plan.located(pet:petPanel.frame,screen:screen),display:true)
        guard petScene.playSideHide(graphID:plan.graphID,mood:engine.presentationMood) else { cancelMovement();restoreBaseAnimation(force:true);return false }
        return true
    }
    @discardableResult private func recoverSideHide() -> Bool {
        guard sideHidePlan != nil else { return false }
        cancelMovement();autonomy.reset();persistPosition();petScene.finishSideHide()
        return true
    }
    private func beginClimbing(_ plan:PetClimbPlan) {
        if edgeScreen == nil { edgeScreen=petPanel.screen?.visibleFrame }
        walkPlan=nil;climbPlan=plan;climbLocated=false;needsEdgeRecovery=true
        moveCycles.begin(distance:plan.distance)
        petScene.playMovement(.climb,graphID:plan.graphID,mood:engine.presentationMood)
    }
    @discardableResult private func chooseMovement(previous:PetMovementChoice?=nil) -> Bool {
        guard let screen=edgeScreen ?? petPanel.screen?.visibleFrame else { return false }
        let candidates=previous?.compatible(mood:engine.presentationMood,pet:petPanel.frame,screen:screen)
            ?? PetMovementChoice.candidates(mood:engine.presentationMood,pet:petPanel.frame,screen:screen)
        guard !candidates.isEmpty else { return false }
        let value=moveRandom.unit(),unit=value.isFinite ? min(1.0.nextDown,max(0,value)):0
        edgeScreen=screen
        switch candidates[Int(unit*Double(candidates.count))] {
        case .walk(let plan):beginWalking(plan)
        case .traversal(let plan):beginClimbing(plan)
        }
        return true
    }
    private func beginWalking(_ plan:PetWalkPlan) {
        cancelMovement(reposition:false);walkPlan=plan;needsEdgeRecovery=true;moveCycles.begin(distance:plan.distance)
        petScene.playMovement(plan.action,graphID:plan.graphID,mood:engine.presentationMood)
    }
    private func endWalking() {
        walkPlan=nil;climbPlan=nil
        if petScene.isMovementAnimation { petScene.finishAction() }
        else { cancelMovement();restoreBaseAnimation() }
        persistPosition()
    }
    private func movementLoop() -> Bool {
        guard (walkPlan != nil || climbPlan != nil),visible,!suspended,autoMove,!petView.isInteracting,engine.presentationMood != .ill else { walkPlan=nil;climbPlan=nil;return false }
        if moveCycles.continueAfterLoop() { return true }
        let previous:PetMovementChoice?=climbPlan.map(PetMovementChoice.traversal) ?? walkPlan.map(PetMovementChoice.walk)
        if let previous,moveCycles.triesCompatibility(),chooseMovement(previous:previous) { return true }
        walkPlan=nil;climbPlan=nil;persistPosition();return false
    }
    @objc func toggleVisibility() {
        petView.cancelInteraction()
        speech.hide();toolbar?.hide();dialogue.resetTiming()
        visible.toggle(); menuVisibility.title = visible ? "隐藏桌宠" : "显示桌宠"
        cancelMovement(); autonomy.reset()
        if visible { restoreBaseAnimation(force:true); petView.isPaused = false; petPanel.orderFrontRegardless() }
        else { petPanel.orderOut(nil); petView.isPaused = true; petScene.releaseTextures() }
    }
    func updateSize() {
        cancelMovement();restoreBaseAnimation(force:true)
        size = min(500, max(150, size)); if !smokeMode { UserDefaults.standard.set(size, forKey: "petSize") }
        petPanel.setContentSize(NSSize(width: size, height: size)); clampPosition(); updateTextureResolution()
    }
    private func updateTextureResolution() {
        petScene.setTextureResolution(pixelWidth: Int(size * (petPanel.screen?.backingScaleFactor ?? 2)))
    }
    private func applyWindowPreferences() {
        let behavior=windowBehavior
        petPanel.level=behavior.topMost ? .floating:.normal
        petPanel.alphaValue=behavior.opacity
        petPanel.ignoresMouseEvents=behavior.ignoresMouse(interacting:petView.isInteracting,opaque:petView.opaqueUnderMouse())
        speech.setTopMost(behavior.topMost);toolbar?.setTopMost(behavior.topMost)
    }
    func updateWindowPreferences() {
        petView.cancelInteraction();cancelMovement();restoreBaseAnimation(force:true)
        opacity=windowBehavior.opacity;applyWindowPreferences();persistPosition()
        if !smokeMode {
            UserDefaults.standard.set(topMost,forKey:"topMost")
            UserDefaults.standard.set(passThrough,forKey:"passThrough")
            UserDefaults.standard.set(opacity,forKey:"opacity")
        }
    }
    @objc func resetWindowPreferences() {
        topMost=true;passThrough=false;opacity=1
        updateWindowPreferences()
        if visible { petPanel.orderFrontRegardless() }
    }
    func updateSimulationSettings() {
        cancelInventoryUse();petView.cancelInteraction();cancelMovement();autonomy.reset()
        engine.configureSimulation(enabled:simulationEnabled,fixedMood:fixedMood)
        state=engine.state;consumeEvents();restoreBaseAnimation(force:true);save()
        if !smokeMode {
            UserDefaults.standard.set(simulationEnabled,forKey:"simulationEnabled")
            UserDefaults.standard.set(fixedMood.rawValue,forKey:"fixedMood")
        }
    }
    func updateInteractionCycle() {
        interactionCycle=min(1000,max(30,interactionCycle))
        autonomy.setInteractionCycle(interactionCycle)
        if !smokeMode { UserDefaults.standard.set(interactionCycle,forKey:"interactionCycle") }
    }
    func updateAutoMove() {
        if !smokeMode { UserDefaults.standard.set(autoMove, forKey: "autoMove") }
        if !autoMove && (walkPlan != nil || climbPlan != nil || (needsEdgeRecovery && sideHidePlan == nil)) { cancelMovement();restoreBaseAnimation(force:true);persistPosition() }
    }
    @objc func resetPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        cancelMovement();restoreBaseAnimation(force:true)
        petPanel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - size - 30, y: screen.visibleFrame.minY + 30)); persistPosition()
    }
    private func clampPosition() {
        if needsEdgeRecovery,let screen=edgeScreen { petPanel.setFrame(PetClimbPlan.recovered(pet:petPanel.frame,screen:screen),display:true);return }
        guard let screen = NSScreen.screens.max(by: { intersectionArea($0.visibleFrame) < intersectionArea($1.visibleFrame) }) else { return }
        let visible = screen.visibleFrame, frame = petPanel.frame
        petPanel.setFrame(PetClimbPlan.recovered(pet:frame,screen:visible),display:true)
    }
    private func intersectionArea(_ rect: NSRect) -> CGFloat { let overlap = rect.intersection(petPanel.frame); return overlap.isNull ? 0 : overlap.width * overlap.height }
    private func persistPosition() {
        guard !smokeMode else { return }
        let frame=needsEdgeRecovery ? edgeScreen.map { PetClimbPlan.recovered(pet:petPanel.frame,screen:$0) } ?? petPanel.frame : petPanel.frame
        UserDefaults.standard.set(frame.minX, forKey: "petX"); UserDefaults.standard.set(frame.minY, forKey: "petY")
    }
    private func suspend() { cancelInventoryUse();petView.cancelInteraction();speech.hide();toolbar?.hide();dialogue.resetTiming();save(); suspended = true; cancelMovement(); autonomy.reset(); petView.isPaused = true; petScene.releaseTextures() }
    private func resume() {
        engine.resetClock();dialogue.resetTiming(); lastTick = nil; lastSave = ProcessInfo.processInfo.systemUptime
        autonomy.reset(); suspended = false
        restoreBaseAnimation(force:true); petView.isPaused = !visible; clampPosition()
    }
    @discardableResult func save() -> Bool {
        guard writable else { return false }
        do { try store.save(engine.state);return true }
        catch { message = "保存失败：\(error.localizedDescription)"; NSLog("%@", message);return false }
    }
    func stop() { cancelInventoryUse();cancelMovement();speech.hide();toolbar?.hide();petView?.cancelInteraction();timer?.cancel(); if engine != nil { save() }; persistPositionIfReady() }
    private func persistPositionIfReady() { if petPanel != nil { persistPosition() } }
    @objc func showControls() {
        if controls == nil {
            let hosting = NSHostingController(rootView: ControlsView(model: self))
            let window = NSWindow(contentViewController: hosting); window.title = "iPet · 状态与设置"
            window.styleMask = [.titled, .closable, .resizable]; window.minSize = NSSize(width: 620, height: 580); window.isReleasedWhenClosed = false; window.center(); controls = window
        }
        NSApp.activate(ignoringOtherApps: true); controls?.makeKeyAndOrderFront(nil)
    }
    private func playTestAction(_ action: PetAction, mood: PetMood, index: Int) {
        if action == .activity, !catalog.activities.isEmpty {
            let activity = catalog.activities[(index / PetAction.allCases.count) % catalog.activities.count]
            petScene.playActivity(graphID: activity.graphID, mood: mood)
            return
        }
        if [.eat, .drink, .gift].contains(action) {
            let items = catalog.items.filter { $0.graphID.lowercased() == action.rawValue && $0.imagePath != nil }
            if !items.isEmpty {
                let item = items[(index / PetAction.allCases.count) % items.count]
                petScene.setFoodImage(path: item.imagePath)
                NSLog("IPET_TEST_ITEM action=%@ item=%@", action.rawValue, item.name)
            } else { petScene.setFoodImage(path: nil) }
        }
        petScene.play(action, mood: mood)
    }
    private func startSmokeTest() {
        // Isolated save path; exercise rendering, interruption, visibility and lifecycle without touching user saves.
        Task { @MainActor in
            for action in PetAction.allCases {
                playTestAction(action, mood: .normal, index: 0)
                try? await Task.sleep(for: .milliseconds(350))
            }
            petScene.setFoodImage(path: catalog.items.first { $0.graphID.lowercased() == "eat" }?.imagePath)
            command(.feed)
            petScene.setFoodImage(path: catalog.items.first { $0.graphID.lowercased() == "drink" }?.imagePath)
            command(.water); command(.toggleRest)
            toggleVisibility(); toggleVisibility(); suspend(); resume()
            save(); showControls()
            NSLog("IPET_SMOKE_OK cacheBytes=%d state=%@", petScene.cacheBytes, state.mood.rawValue)
            if let raw = ProcessInfo.processInfo.environment["IPET_SOAK_SECONDS"], let seconds = Int(raw), seconds > 0 {
                let began = ProcessInfo.processInfo.systemUptime
                var index = 0
                while ProcessInfo.processInfo.systemUptime - began < Double(seconds) {
                    playTestAction(PetAction.allCases[index % PetAction.allCases.count], mood: PetMood.allCases[(index / PetAction.allCases.count) % PetMood.allCases.count], index: index)
                    if index % 10 == 0 { toggleVisibility(); toggleVisibility() }
                    if index % 20 == 0 { suspend(); resume() }
                    if index % 15 == 0 { NSLog("IPET_SOAK_SAMPLE cacheBytes=%d", petScene.cacheBytes) }
                    index += 1
                    try? await Task.sleep(for: .seconds(3))
                }
                NSLog("IPET_SOAK_DONE elapsed=%.1f cacheBytes=%d", ProcessInfo.processInfo.systemUptime - began, petScene.cacheBytes)
                NSApp.terminate(nil)
            }
        }
    }
}
