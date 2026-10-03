// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import AppKit
import ColorSync
import SwiftUI
import Combine
import SpriteKit
import UniformTypeIdentifiers
import PetCore
import PetRendering
import PetMacInput

enum ControlPage: String, CaseIterable { case diagnostics="诊断",status="状态", activity="活动", schedule="日程", shortcuts="快捷", shop="商店", inventory="背包", settings="设置", statistics="统计" }

@MainActor final class AppModel: ObservableObject {
    @Published var state = PetState()
    @Published private(set) var diagnostics=PetDiagnostics()
    @Published private(set) var shortcuts=PetShortcutList()
    @Published private(set) var shortcutError=""
    @Published private(set) var shortcutsEditable=true
    let keyboardSender=PetKeyboardSender()
    private var shortcutStore:PetShortcutStore!
    private var shortcutMenu:NSMenu?
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
    @Published var speechPlacement:SpeechPlacement.Mode = .automatic
    @Published var speechInteractive=false
    @Published var autoChangeScreen=false
    private var activeScreenID:String?
    @Published var movementAreaMode:PetMovementAreaMode = .current
    @Published private(set) var movementAreaNotice=""
    private var customMovementArea:CGRect?
    private var movementAreaWindow:PetMovementAreaWindow?
    @Published var smartMoveEnabled=false
    @Published var smartMoveInterval=1200
    @Published private(set) var smartMovePaused=false
    private let smartMove=PetSmartMove()
    private var movementEnabled:Bool { autoMove && smartMove.allowsMovement }
    @Published var visible = true
    @Published var toolbarEnabled=false
    @Published private(set) var favoriteItems:Set<String>=[]
    @Published private(set) var favoriteActivities:Set<String>=[]
    @Published private(set) var packageWriteFailed=false
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
    private var reposition=PetReposition()
    private var needsEdgeRecovery=false
    private var moveRandom=SeededPetRandom(seed:UInt64.random(in:0...UInt64.max))
    private let autonomy = PetAutonomy()
    private var dialogue:PetDialogue!
    private let speech=PetSpeechWindow()
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
        favoriteActivities = smokeMode ? []:Set(defaults.stringArray(forKey:"favoriteActivities") ?? [])
        topMost=smokeMode ? true:(defaults.object(forKey:"topMost") as? Bool ?? true)
        passThrough = !smokeMode && defaults.bool(forKey:"passThrough")
        opacity=smokeMode ? 1:PetWindowBehavior(opacity:defaults.object(forKey:"opacity") as? Double ?? 1).opacity
        simulationEnabled=smokeMode ? true:(defaults.object(forKey:"simulationEnabled") as? Bool ?? true)
        fixedMood=smokeMode ? .normal:(PetMood(rawValue:defaults.string(forKey:"fixedMood") ?? "") ?? .normal)
        interactionCycle=smokeMode ? 200:min(1000,max(30,defaults.object(forKey:"interactionCycle") as? Int ?? 200))
        speechPlacement=smokeMode ? .automatic:(SpeechPlacement.Mode(rawValue:defaults.string(forKey:"speechPlacement") ?? "") ?? .automatic)
        speechInteractive = !smokeMode && defaults.bool(forKey:"speechInteractive")
        autoChangeScreen = !smokeMode && (defaults.object(forKey:"autoChangeScreen") as? Bool ?? false)
        activeScreenID=smokeMode ? nil:PetScreenChange.persistedIdentity(defaults.string(forKey:"activeScreenID"))
        movementAreaMode=smokeMode ? .current:(PetMovementAreaMode(rawValue:defaults.string(forKey:"movementAreaMode") ?? "") ?? .current)
        if !smokeMode,let values=defaults.array(forKey:"customMovementArea") as? [Double],values.count == 4 { customMovementArea=CGRect(x:values[0],y:values[1],width:values[2],height:values[3]) }
        smartMoveEnabled = !smokeMode && defaults.bool(forKey:"smartMoveEnabled")
        let interval=defaults.object(forKey:"smartMoveInterval") as? Int ?? 1200
        smartMoveInterval=smokeMode ? 1200:(PetSmartMove.intervals.contains(interval) ? interval:1200)
    }
    func start() throws {
        smartMove.configure(allowMove:autoMove,enabled:smartMoveEnabled,interval:smartMoveInterval)
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
        shortcutStore=PetShortcutStore(directory:base);reloadShortcuts()
        store = PetSaveStore(directory: base)
        do { state = try store.load() ?? PetState(); message = store.recoveryMessage ?? "" }
        catch { writable = false; message = "\(error.localizedDescription) 本次仅运行，存档写入已暂停。";recordDiagnostic(.save,message) }
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("PetAssets") else { throw PetSaveError.invalidDocument }
        assetRoot = root
        catalog = try PetCatalog.load(from: root.appendingPathComponent("gameplay.json"))
        engine = PetEngine(state: state, catalog: catalog)
        engine.configureSimulation(enabled:simulationEnabled,fixedMood:fixedMood)
        state=engine.state
        dialogue=PetDialogue(catalog:try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json")))
        petScene = PetScene(manifest: try PetManifest.load(from: root), assetRoot: root)
        petScene.onDiagnostic = { [weak self] text in self?.recordDiagnostic(.rendering,text);NSLog("%@",text) }
        petScene.play(state.resting ? .sleep : .idle, mood: presentationMood)
        speech.setPlacement(speechPlacement)
        speech.setInteractive(speechInteractive)
        speech.onCloseRequested = { [weak self] in self?.closeSpeech() }
        speech.onRevealFinished = { [weak self] in self?.petScene.finishSpeech() }
        petScene.onIdleCycle = { [weak self] in self?.autonomy.recordIdleCycle() }
        petScene.onPinchLoop = { [weak self] in
            guard let self,self.visible,!self.suspended,self.petView.isInteracting,!self.petView.isDragging else { return false }
            self.applyPinchEffects();return true
        }
        petScene.onMovementLoop = { [weak self] in self?.movementLoop() ?? false }
        petScene.onMovementCompleted = { [weak self] in
            guard let self,self.visible,!self.suspended,self.movementEnabled,!self.petView.isInteracting,
                  self.needsEdgeRecovery,let screen=self.edgeScreen else { return false }
            return self.beginSideHide(screen:screen)
        }
        petScene.onMovementFailed = { [weak self] in
            guard let self else { return };self.cancelMovement();self.clampPosition();self.persistPosition()
        }
        petScene.onActionFinished = { [weak self] action in
            guard let self else { return }
            if [.walkLeft,.walkRight,.climb].contains(action) {
                self.cancelMovement(reposition:false);self.needsEdgeRecovery=false;self.edgeScreen=nil;self.persistPosition()
            } else if action == .sideHide { self.cancelMovement();self.persistPosition() }
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
        petView.onPressBegin = { [weak self] in self?.petScene.discardSpeechStart();self?.engine.recordInteraction();self?.autonomy.reset() }
        petView.onMovementInteraction = { [weak self] in
            guard let self else { return }
            self.smartMove.interactionEnded(raised:false);self.smartMovePaused=self.smartMove.isTimedOut
        }
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
        petView.raiseAnchor = { [weak self] in
            guard let self else { return nil }
            return self.petScene.manifest.raiseAnchors?[self.engine.presentationMood.rawValue]
        }
        petView.onDragStart = { [weak self] in
            guard let self else { return }
            self.toolbar?.hide()
            self.recordAcceptanceInput("drag-start")
            self.engine.recordInteraction(); self.autonomy.reset();
            self.cancelMovement(reposition:false); self.petScene.beginRaise(mood:self.engine.presentationMood)
            if self.petScene.manifest.raiseAnchors?[self.engine.presentationMood.rawValue] == nil {
                self.petScene.onDiagnostic?("资源缺少提起锚点，沿用点击处拖动。")
            }
        }
        petView.onDragMotion = { [weak self] distance in self?.petScene.updateRaiseMotion(distance:distance) }
        petView.onDragEnd = { [weak self] in
            guard let self else { return }
            self.needsEdgeRecovery=false;self.edgeScreen=nil
            if let area=self.movementArea,let primary=NSScreen.screens.first?.visibleFrame {
                self.reposition.raised(pet:self.petPanel.frame,area:area,primary:primary)
            }
            if !self.beginSideHide() { self.petScene.finishRaise();self.recoverInvisiblePlacement() };self.persistPosition()
            self.recordAcceptanceInput("drag-end")
        }
        if let x = UserDefaults.standard.object(forKey: "petX") as? Double, let y = UserDefaults.standard.object(forKey: "petY") as? Double {
            petPanel.setFrameOrigin(NSPoint(x: x, y: y)); clampPosition()
        } else { resetPosition() }
        if activeScreenID == nil { synchronizeActiveScreen() }
        refreshMovementAreaNotice()
        petPanel.orderFrontRegardless()
        toolbar=PetToolbarWindow { [weak self] action in self?.toolbarAction(action) }
        applyWindowPreferences()
        refreshToolbar()
        updateTextureResolution()
        buildMenu()
        keyboardSender.onStatus = { [weak self] text in self?.message=text;self?.recordDiagnostic(.keyboard,text);self?.refreshToolbar() }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] _ in MainActor.assumeIsolated { self?.keyboardSender.frontmostApplicationChanged() } })
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.suspend() } })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.resume() } })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.edgeScreen=nil;self?.cancelMovement();self?.clampPosition();self?.refreshMovementAreaNotice();self?.restoreBaseAnimation(force:true); self?.updateTextureResolution() } })
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
        menu.addItem(item("日程…",#selector(showSchedule)));menu.addItem(item("活动…", #selector(showActivities))); menu.addItem(item("商店…", #selector(showShop)))
        menu.addItem(item("背包…", #selector(showInventory)))
        menu.addItem(item("统计与历史…", #selector(showStatistics)))
        menu.addItem(item("本机诊断与报告…",#selector(showDiagnostics)))
        let custom=NSMenuItem(title:"自定义快捷",action:nil,keyEquivalent:"")
        shortcutMenu=NSMenu(title:"自定义快捷");shortcutMenu?.autoenablesItems=false;custom.submenu=shortcutMenu;menu.addItem(custom)
        rebuildShortcutMenu()
        menu.addItem(item("聊一句", #selector(sayClick)))
        menu.addItem(item("关闭说话", #selector(closeSpeech)))
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
    func reloadShortcuts() {
        guard shortcutStore != nil else { return }
        do { shortcuts=try shortcutStore.load();shortcutsEditable=true;shortcutError="";rebuildShortcutMenu() }
        catch { shortcutsEditable=false;shortcutError="快捷配置读取失败：\(error.localizedDescription) 原文件与上次已读取列表已保留。";recordDiagnostic(.shortcut,shortcutError) }
    }
    @discardableResult func editShortcut(_ action:PetShortcutEdit) -> Bool {
        guard shortcutsEditable,shortcutStore != nil else { return false }
        do {
            var next=shortcuts;try next.edit(action);try shortcutStore.save(next)
            shortcuts=next;shortcutError="";message="快捷入口已保存。";rebuildShortcutMenu();refreshToolbar();return true
        } catch { shortcutError="快捷入口保存失败：\(error.localizedDescription) 已保存列表未改变。";recordDiagnostic(.shortcut,shortcutError);return false }
    }
    func runShortcut(_ id:Int) {
        guard let entry=shortcuts.entries.first(where:{ $0.id==id }) else { message="快捷入口已不存在。";return }
        do {
            try entry.validate()
            if entry.kind == .macKeys {
                guard visible,!suspended else { message="请先显示桌宠并唤醒后再发送按键。";return }
                _=keyboardSender.start(try PetKeyboardMacro.decodeTarget(entry.target),name:entry.name);return
            }
            keyboardSender.cancel()
            let url=try entry.resolvedURL()
            if url.isFileURL,!FileManager.default.fileExists(atPath:url.path) { message="目标路径不存在，记录仍保留：\(entry.name)。";recordDiagnostic(.shortcut,message);return }
            guard NSWorkspace.shared.open(url) else { message="系统无法打开目标，记录仍保留：\(entry.name)。";recordDiagnostic(.shortcut,message);return }
            message="已向系统请求打开：\(entry.name)。"
        } catch { message="打开快捷入口失败：\(error.localizedDescription)";recordDiagnostic(.shortcut,message) }
    }
    func recordDiagnostic(_ kind:PetDiagnosticKind,_ text:String) { diagnostics.record(kind,text,at:Date()) }
    func clearDiagnostics() { diagnostics.clear() }
    @objc private func showDiagnostics() { selectedPage = .diagnostics;showControls() }
    func diagnosticReport(description:String,includeLogs:Bool) throws -> String {
        let clips=petScene?.manifest.clips ?? []
        let paths=Set(clips.flatMap { clip in clip.stages.flatMap { stage in (stage.layers+(stage.variants ?? []).flatMap { $0 }).flatMap { $0.frames.map(\.path) } } })
        let report=PetDiagnosticReport(appVersion:Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "未知",systemVersion:ProcessInfo.processInfo.operatingSystemVersionString,clips:clips.count,frames:paths.count,items:catalog.items.count,simulationEnabled:simulationEnabled,visible:visible,writable:writable,saveFailed:packageWriteFailed)
        return try report.text(log:diagnostics,description:description,includeLogs:includeLogs,at:Date())
    }
    func exportDiagnosticReport(_ preview:String) {
        guard !preview.isEmpty,store != nil else { message="请先生成报告预览。";return }
        let panel=NSSavePanel();panel.allowedContentTypes=[.plainText];panel.nameFieldStringValue="iPet-report.txt"
        guard panel.runModal() == .OK,let url=panel.url else { return }
        do { try PetDiagnosticReport.writePreview(preview,to:url,protectedDirectory:store.directory);message="已导出预览报告，未上传。" }
        catch { message="报告导出失败：\(error.localizedDescription)" }
    }
    func openShortcutFolder() {
        do {
            try FileManager.default.createDirectory(at:shortcutStore.directory,withIntermediateDirectories:true)
            message=NSWorkspace.shared.open(shortcutStore.directory) ? "已请求打开快捷配置目录。":"系统无法打开快捷配置目录。"
        }
        catch { shortcutError="无法打开配置目录：\(error.localizedDescription)" }
    }
    func restoreShortcuts() {
        let alert=NSAlert();alert.messageText="恢复上一份快捷入口备份？"
        alert.informativeText="只恢复快捷列表，宠物存档不变。当前快捷配置会独立保留原件；未来版本不会覆盖。"
        alert.addButton(withTitle:"恢复并保留原件");alert.addButton(withTitle:"取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { shortcuts=try shortcutStore.restoreBackup();shortcutsEditable=true;shortcutError="";message="快捷入口备份已恢复，原件已保留。";rebuildShortcutMenu();refreshToolbar() }
        catch { shortcutError="恢复快捷备份失败：\(error.localizedDescription)" }
    }
    private func rebuildShortcutMenu() {
        guard let menu=shortcutMenu else { return };menu.removeAllItems()
        for entry in shortcuts.entries {
            let item=NSMenuItem(title:entry.name,action:#selector(runShortcutMenu(_:)),keyEquivalent:"")
            item.target=self;item.tag=entry.id;item.isEnabled=entry.kind != .windowsKeys;menu.addItem(item)
        }
        if !shortcuts.entries.isEmpty { menu.addItem(.separator()) }
        let stopKeys=NSMenuItem(title:"停止剩余按键",action:#selector(stopKeyboard),keyEquivalent:"");stopKeys.target=self;menu.addItem(stopKeys)
        let manage=NSMenuItem(title:"管理快捷入口…",action:#selector(showShortcuts),keyEquivalent:"");manage.target=self;menu.addItem(manage)
    }
    @objc private func stopKeyboard() { keyboardSender.cancel() }
    @objc private func runShortcutMenu(_ sender:NSMenuItem) { runShortcut(sender.tag) }
    var scheduleAccess:PetScheduleAccess {
        PetScheduleAccess(writable:writable,saveFailed:packageWriteFailed,busy:inventoryUseTask != nil,simulationEnabled:simulationEnabled)
    }
    var packageOperationsEnabled:Bool { writable && !packageWriteFailed && inventoryUseTask == nil }
    func signPackage(id:String,level:Int) {
        guard packageOperationsEnabled,let definition=catalog.packageDefinition(id) else { message="套餐操作暂不可用，请检查存档写入和背包使用状态。";return }
        var confirmed=false
        if let old=engine.state.package(definition.kind),old.isActive(at:Date()) {
            let alert=NSAlert();alert.messageText="替换仍有效的套餐？"
            let quote=definition.quote(level:level,now:Date()),refund=PetPackageRules.refund(contract:old,catalog:catalog,now:Date())
            alert.informativeText="原套餐：\(old.name)\n新套餐：\(definition.name) · 全价\((quote?.price ?? 0).formatted(.number.precision(.fractionLength(2))))金币\n预计退款\(refund.formatted(.number.precision(.fractionLength(2))))金币。需先满足全价余额；确认时按最新状态和时间重新校验。"
            if catalog.packageDefinition(old.definitionID)==nil { alert.informativeText += "\n旧套餐定义未识别，退款按0处理。" }
            alert.addButton(withTitle:"确认替换");alert.addButton(withTitle:"取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            confirmed=true
        }
        perform(.signPackage(id,level:level,replace:confirmed))
    }
    func perform(_ command: PetEconomyCommand) {
        switch command {
        case .schedule(let action):
            guard scheduleAccess.allows(action,state:engine.state) else { message="日程操作暂不可用，请检查运行状态、队列、存档写入和背包使用状态。";return }
        case .resumeActivity where engine.state.activity?.scheduleEntryID != nil:
            guard scheduleAccess.allows(.resume,state:engine.state) else { message="请先恢复存档写入，再继续日程活动。";return }
        case .signPackage,.setPackageAutoRenew,.renewPackages:
            guard packageOperationsEnabled else { message="套餐操作已暂停，请检查存档写入和背包使用状态。";return }
            let response=engine.perform(command);state=engine.state;message=response.message
            if response.accepted,!save() { packageWriteFailed=true;message += " 套餐变更已保留在内存，暂停后续套餐操作，请重试保存，避免再次扣款。" }
            return
        default:break
        }
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
    func toggleFavoriteActivity(id:String) {
        guard catalog.activity(id) != nil else { return }
        if favoriteActivities.contains(id) { favoriteActivities.remove(id) } else { favoriteActivities.insert(id) }
        if !smokeMode { UserDefaults.standard.set(favoriteActivities.sorted(),forKey:"favoriteActivities") }
    }
    func itemMultiplier(id: String) -> Double {
        guard let item=catalog.item(id) else { return 0 }
        return PetItemRules.multiplier(category:item.category,expiry:state.itemCooldowns[id],now:Date())
    }
    @discardableResult private func consumeEvents() -> Bool {
        var usedItem = false, stopped = false, scheduleChanged=false
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
            case .scheduleChanged(let notice): scheduleChanged=true;message=notice
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
        if stopped || scheduleChanged {
            state = engine.state
            if stopped {
                if !usedItem && !petScene.finishActivity() { restoreBaseAnimation() }
            } else if !usedItem { cancelMovement();autonomy.reset();restoreBaseAnimation(force:true) }
            save()
        }
        return usedItem
    }
    private func restoreBaseAnimation(force: Bool = false) {
        guard petScene != nil, sideHidePlan == nil, petView?.isInteracting != true else { return }
        _ = petScene.restoreBase(state:engine.state,catalog:catalog,force:force,mood:presentationMood)
    }
    @objc private func showShortcuts() { selectedPage = .shortcuts;showControls() }
    @objc private func showSchedule() { selectedPage = .schedule;showControls() }
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
    @objc func closeSpeech() {
        petScene?.discardSpeechStart();petScene?.finishSpeech();speech.hide()
    }
    func updateSpeechInteraction() {
        speech.setInteractive(speechInteractive)
        if !smokeMode { UserDefaults.standard.set(speechInteractive,forKey:"speechInteractive") }
    }
    func updateSpeechPlacement() {
        speech.setPlacement(speechPlacement)
        if speech.isVisible,let screen=companionScreen { speech.updatePosition(petFrame:speechAnchor,screen:screen) }
        if !smokeMode { UserDefaults.standard.set(speechPlacement.rawValue,forKey:"speechPlacement") }
    }
    private func showSpeech(_ text:String) {
        guard visible,!suspended,companionScreen != nil else { return }
        petScene.discardSpeechStart();speech.hide()
        if !petView.isInteracting,petScene.playSpeech(mood:presentationMood,onReady:{ [weak self] in self?.presentSpeech(text) }) { return }
        presentSpeech(text)
    }
    private func presentSpeech(_ text:String) {
        guard visible, !suspended, let screen=companionScreen else { return }
        if text.count>4000 { recordDiagnostic(.rendering,"说话内容超过显示上限，仅显示前4000字符。") }
        speech.show(text:text,name:engine.state.name,petFrame:speechAnchor,screen:screen)
    }
    private var companionScreen:CGRect? { petPanel?.screen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame }
    private var speechAnchor:CGRect { speechPlacement == .automatic ? toolbar?.visibleFrame.map { petPanel.frame.union($0) } ?? petPanel.frame : petPanel.frame }
    @objc func toggleToolbar() { toolbarEnabled.toggle();updateToolbarPreference() }
    func updateToolbarPreference() {
        if !smokeMode { UserDefaults.standard.set(toolbarEnabled,forKey:"toolbarEnabled") }
        menuToolbar?.state=toolbarEnabled ? .on : .off
        refreshToolbar()
    }
    private func refreshToolbar() {
        guard toolbarEnabled,visible,!suspended,petView?.isInteracting != true,let screen=companionScreen,engine != nil else { toolbar?.hide();return }
        toolbar?.update(state:engine.state,catalog:catalog,message:message,shortcuts:shortcuts.entries,petFrame:petPanel.frame,screen:screen)
    }
    private func toolbarAction(_ action:ToolbarAction) {
        switch action {
        case .status: selectedPage = .status;showControls()
        case .activity: showActivities()
        case .shop: showShop()
        case .inventory: showInventory()
        case .shortcuts: showShortcuts()
        case .shortcut(let id): runShortcut(id)
        case .stopKeyboard: keyboardSender.cancel()
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
        smartMove.tick()
        if smartMovePaused != smartMove.isTimedOut { smartMovePaused=smartMove.isTimedOut }
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - (lastTick ?? now), 0), 0.1); lastTick = now
        if speech.isVisible {
            speech.advance(to:now)
            if speech.isVisible,let screen=companionScreen { speech.updatePosition(petFrame:speechAnchor,screen:screen) }
        }
        let oldMood = engine.presentationMood
        if (!writable || packageWriteFailed),engine.state.schedule?.isRunning == true,engine.state.schedule?.isPaused == false {
            _=engine.perform(.schedule(.pause))
        }
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
                if !movementEnabled || petView.isInteracting || !petScene.isMovementAnimation { endWalking() }
                else if petScene.currentPhase == .loop,let screen=edgeScreen {
                    if let frame=plan.advance(pet:petPanel.frame,screen:screen,seconds:delta) { petPanel.setFrame(frame,display:true) }
                    else {
                        if !moveCycles.triesCompatibility() || !chooseMovement(previous:.walk(plan)) { endWalking() }
                    }
                }
            }
            if let plan=climbPlan {
                if !movementEnabled || petView.isInteracting || !petScene.isMovementAnimation || engine.presentationMood == .ill { endWalking() }
                else if petScene.currentPhase == .loop,let screen=edgeScreen {
                    if !climbLocated { petPanel.setFrame(plan.located(pet:petPanel.frame,screen:screen),display:true);climbLocated=true }
                    if let frame=plan.advance(pet:petPanel.frame,screen:screen,seconds:delta) { petPanel.setFrame(frame,display:true) }
                    else if !moveCycles.triesCompatibility() || !chooseMovement(previous:.traversal(plan)) { endWalking() }
                }
            }
        }
        let eligible = !manualTest && PetAutonomy.canStart(state:engine.state,action:petScene.requestedAction,visible:visible,interacting:petView.isInteracting,finishing:petScene.isFinishingActivity)
        if let entry=dialogue.automatic(state:engine.state,eligible:eligible && !speech.isVisible,mood:presentationMood) { showSpeech(entry.rendered(state:engine.state)) }
        let autonomyEligible = !manualTest && PetAutonomy.canStart(state:engine.state,action:petScene.requestedAction,visible:visible,interacting:petView.isInteracting,finishing:petScene.isFinishingActivity)
        if let behavior = autonomy.poll(eligible:autonomyEligible,allowsMovement:movementEnabled,mood:engine.presentationMood,working:petScene.requestedAction == .activity) {
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
        if reposition {
            if needsEdgeRecovery { clampPosition() }
            needsEdgeRecovery=false;edgeScreen=nil
        }
    }
    private func beginSideHide(screen pinnedScreen:CGRect?=nil) -> Bool {
        let activated=activateScreenAtEdgeCheck()
        guard let screen=activated ?? pinnedScreen ?? movementArea,
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
        if edgeScreen == nil { edgeScreen=movementArea }
        walkPlan=nil;climbPlan=plan;climbLocated=false;needsEdgeRecovery=true
        moveCycles.begin(distance:plan.distance)
        petScene.playMovement(.climb,graphID:plan.graphID,mood:engine.presentationMood)
    }
    @discardableResult private func chooseMovement(previous:PetMovementChoice?=nil) -> Bool {
        guard movementEnabled else { return false }
        guard let screen=edgeScreen ?? movementArea else { return false }
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
    private func stopMovementPosition() {
        guard walkPlan != nil || climbPlan != nil else { return }
        if let area=edgeScreen ?? movementArea,let primary=NSScreen.screens.first?.visibleFrame {
            petPanel.setFrame(reposition.stop(pet:petPanel.frame,area:area,primary:primary),display:true)
        }
    }
    private func recoverInvisiblePlacement() {
        let frame=petPanel.frame
        let visibleOnScreen=NSScreen.screens.contains { screen in
            let intersection=screen.frame.intersection(frame)
            return !intersection.isNull && intersection.width>0 && intersection.height>0
        }
        if !visibleOnScreen { clampPosition();reposition.reset() }
    }
    private func endWalking() {
        stopMovementPosition();walkPlan=nil;climbPlan=nil
        if petScene.isMovementAnimation { petScene.finishAction() }
        else { cancelMovement();restoreBaseAnimation() }
        persistPosition()
    }
    private func movementLoop() -> Bool {
        guard (walkPlan != nil || climbPlan != nil),visible,!suspended,movementEnabled,!petView.isInteracting,engine.presentationMood != .ill else {
            if !petView.isInteracting { stopMovementPosition() }
            walkPlan=nil;climbPlan=nil;return false
        }
        if moveCycles.continueAfterLoop() { return true }
        let previous:PetMovementChoice?=climbPlan.map(PetMovementChoice.traversal) ?? walkPlan.map(PetMovementChoice.walk)
        if let previous,moveCycles.triesCompatibility(),chooseMovement(previous:previous) { return true }
        stopMovementPosition();walkPlan=nil;climbPlan=nil;persistPosition();return false
    }
    @objc func toggleVisibility() {
        keyboardSender.cancel()
        petView.cancelInteraction()
        petScene?.discardSpeechStart();speech.hide();toolbar?.hide();dialogue.resetTiming()
        visible.toggle(); menuVisibility.title = visible ? "隐藏桌宠" : "显示桌宠"
        cancelMovement(); autonomy.reset()
        if visible { restoreBaseAnimation(force:true); petView.isPaused = false; petPanel.orderFrontRegardless() }
        else { petPanel.orderOut(nil); petView.isPaused = true; petScene.releaseTextures() }
    }
    func updateSize() {
        cancelMovement();restoreBaseAnimation(force:true)
        size = min(500, max(150, size)); if !smokeMode { UserDefaults.standard.set(size, forKey: "petSize") }
        petPanel.setContentSize(NSSize(width: size, height: size)); clampPosition();refreshMovementAreaNotice(); updateTextureResolution()
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
    func updateSmartMoveSettings() {
        smartMove.configure(allowMove:autoMove,enabled:smartMoveEnabled,interval:smartMoveInterval)
        smartMoveInterval=smartMove.interval;smartMovePaused=false
        if walkPlan != nil || climbPlan != nil { endWalking() }
        if !smokeMode {
            UserDefaults.standard.set(smartMoveEnabled,forKey:"smartMoveEnabled")
            UserDefaults.standard.set(smartMoveInterval,forKey:"smartMoveInterval")
        }
    }
    func updateAutoMove() {
        updateSmartMoveSettings()
        if !smokeMode { UserDefaults.standard.set(autoMove, forKey: "autoMove") }
        if !autoMove && (walkPlan != nil || climbPlan != nil || (needsEdgeRecovery && sideHidePlan == nil)) { cancelMovement();restoreBaseAnimation(force:true);persistPosition() }
    }
    private var physicalDisplays:[PetScreenChange.Display] {
        NSScreen.screens.map { screen in
            let identity:String
            if let number=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               let uuid=CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() {
                identity=CFUUIDCreateString(nil,uuid) as String
            } else { identity="" }
            return PetScreenChange.Display(id:identity,frame:screen.visibleFrame)
        }
    }
    private func synchronizeActiveScreen() {
        activeScreenID=PetScreenChange.current(pet:movementArea ?? petPanel.frame,displays:physicalDisplays)?.id
        storeMovementAreaPreference()
    }
    func updateAutoChangeScreen() {
        if !smokeMode { UserDefaults.standard.set(autoChangeScreen,forKey:"autoChangeScreen") }
    }
    private func storeMovementAreaPreference() {
        guard !smokeMode else { return }
        UserDefaults.standard.set(movementAreaMode.rawValue,forKey:"movementAreaMode")
        UserDefaults.standard.set(activeScreenID,forKey:"activeScreenID")
        if let r=customMovementArea { UserDefaults.standard.set([Double(r.minX),Double(r.minY),Double(r.width),Double(r.height)],forKey:"customMovementArea") }
    }
    private func activateScreenAtEdgeCheck() -> CGRect? {
        guard let display=PetScreenChange.target(enabled:autoChangeScreen,blocked:controls?.isVisible == true || movementAreaWindow?.isVisible == true,activeID:activeScreenID,pet:petPanel.frame,displays:physicalDisplays) else { return nil }
        activeScreenID=display.id;customMovementArea=display.frame;movementAreaMode = .custom
        // Retire the old pinned boundary before normal completion recovers the pet.
        if needsEdgeRecovery { edgeScreen=display.frame }
        storeMovementAreaPreference();refreshMovementAreaNotice()
        recordDiagnostic(.lifecycle,"边缘检查自动激活角色所在显示器，更新固定移动范围。")
        return display.frame
    }
    private var areaResolution:PetMovementArea.Resolution {
        PetMovementArea.resolve(mode:movementAreaMode,custom:customMovementArea,pet:petPanel.frame,screens:NSScreen.screens.map(\.visibleFrame))
    }
    private var movementArea:CGRect? { areaResolution.rect }
    private func refreshMovementAreaNotice() {
        let result=areaResolution
        movementAreaNotice=result.adjusted ? "选定范围已裁剪或临时回退到可用屏幕；原设置保留。没有可容纳角色的屏幕时暂停移动。":""
    }
    func updateMovementArea() {
        petView.cancelInteraction();cancelMovement();restoreBaseAnimation(force:true)
        clampPosition();refreshMovementAreaNotice();persistPosition();autonomy.reset()
        synchronizeActiveScreen()
    }
    func detectMovementScreen() {
        guard let screen=petPanel.screen ?? NSScreen.screens.first else { return }
        customMovementArea=screen.visibleFrame;movementAreaMode = .custom;updateMovementArea()
    }
    func selectMovementArea() {
        petView.cancelInteraction();cancelMovement();restoreBaseAnimation(force:true);clampPosition();autonomy.reset()
        movementAreaWindow?.close()
        guard let frame=movementArea else { return }
        let window=PetMovementAreaWindow(frame:frame,minimum:size) { [weak self] rect in
            guard let self else { return };self.customMovementArea=rect;self.movementAreaMode = .custom;self.updateMovementArea()
        }
        movementAreaWindow=window;window.makeKeyAndOrderFront(nil)
    }
    @objc func resetPosition() {
        guard let rect=movementArea else { return }
        cancelMovement();restoreBaseAnimation(force:true)
        petPanel.setFrameOrigin(NSPoint(x:rect.maxX-size-30,y:rect.minY+30));clampPosition();persistPosition()
    }
    private func clampPosition() {
        reposition.reset()
        if needsEdgeRecovery,let screen=edgeScreen { petPanel.setFrame(PetClimbPlan.recovered(pet:petPanel.frame,screen:screen),display:true);return }
        guard let rect=movementArea else { return }
        petPanel.setFrame(PetClimbPlan.recovered(pet:petPanel.frame,screen:rect),display:true)
    }
    private func persistPosition() {
        guard !smokeMode else { return }
        let frame=needsEdgeRecovery ? edgeScreen.map { PetClimbPlan.recovered(pet:petPanel.frame,screen:$0) } ?? petPanel.frame : petPanel.frame
        UserDefaults.standard.set(frame.minX, forKey: "petX"); UserDefaults.standard.set(frame.minY, forKey: "petY")
    }
    private func suspend() { smartMove.pause();recordDiagnostic(.lifecycle,"系统即将睡眠，计时暂停且不补算。");keyboardSender.cancel(); cancelInventoryUse();petView.cancelInteraction();petScene?.discardSpeechStart();speech.hide();toolbar?.hide();dialogue.resetTiming();save(); suspended = true; cancelMovement(); autonomy.reset(); petView.isPaused = true; petScene.releaseTextures() }
    private func resume() {
        smartMove.resume()
        recordDiagnostic(.lifecycle,"系统唤醒，重建计时基准。");
        engine.resetClock();dialogue.resetTiming(); lastTick = nil; lastSave = ProcessInfo.processInfo.systemUptime
        autonomy.reset(); suspended = false
        restoreBaseAnimation(force:true); petView.isPaused = !visible; clampPosition()
    }
    @discardableResult func save() -> Bool {
        guard writable else { return false }
        do { try store.save(engine.state);packageWriteFailed=false;return true }
        catch {
            packageWriteFailed=true
            if engine.state.schedule?.isRunning == true,engine.state.schedule?.isPaused == false { _=engine.perform(.schedule(.pause));state=engine.state }
            message = "保存失败：\(error.localizedDescription)";recordDiagnostic(.save,message);NSLog("%@",message);return false
        }
    }
    func stop() { keyboardSender.cancel(); cancelInventoryUse();cancelMovement();petScene?.discardSpeechStart();speech.hide();toolbar?.hide();petView?.cancelInteraction();timer?.cancel(); if engine != nil { save() }; persistPositionIfReady() }
    private func persistPositionIfReady() { if petPanel != nil { persistPosition() } }
    private func canManageSave() -> Bool {
        guard writable else { message="存档写入已暂停，先处理原文件后再导出或恢复。";return false }
        guard inventoryUseTask == nil else { message="请先完成或停止批量使用，再管理存档。";return false }
        return true
    }
    func exportSave() {
        guard canManageSave() else { return }
        do {
            let data=try store.exportSnapshot(engine.state)
            let panel=NSSavePanel();panel.allowedContentTypes=[.json];panel.nameFieldStringValue="iPet-backup.json"
            guard panel.runModal() == .OK,let url=panel.url else { return }
            guard url.resolvingSymlinksInPath().deletingLastPathComponent() != store.directory.resolvingSymlinksInPath() else {
                message="请导出到存档目录以外的位置，保留应用管理的原件与备份。";return
            }
            try data.write(to:url,options:.atomic)
            message="已导出点击时的存档快照：\(url.lastPathComponent)。"
        } catch { message="导出失败：\(error.localizedDescription)" }
    }
    func restoreSave() {
        guard canManageSave() else { return }
        let panel=NSOpenPanel();panel.allowedContentTypes=[.json];panel.allowsMultipleSelection=false;panel.canChooseDirectories=false
        guard panel.runModal() == .OK,let url=panel.url else { return }
        do {
            let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard size<=PetSaveStore.snapshotSizeLimit else { throw PetSaveError.snapshotTooLarge }
            let data=try Data(contentsOf:url),preview=try store.previewImport(data)
            let alert=NSAlert();alert.messageText="恢复此存档？"
            let quantity=preview.inventory.values.reduce(0,+)
            let unknown=preview.inventory.keys.filter { catalog.item($0) == nil }.count
            alert.informativeText="\(preview.name) · 等级 \(preview.level) · 金币 \(preview.money.formatted(.number.precision(.fractionLength(2))))\n库存 \(quantity) 件，未知物品 \(unknown) 种；导入活动保持暂停。\n当前最新状态和导入原件会独立保留在存档目录。快捷入口列表不随此恢复改变。Windows LPS不支持。"
            if preview.schedule?.isRunning == true { alert.informativeText += "\n导入日程将保持暂停，不自动续费或执行。" }
            if let session=preview.activity { alert.informativeText += "\n导入活动倍率：\(session.effectiveMultiplier)倍。" }
            if !simulationEnabled,preview.activity != nil { alert.informativeText += "\n养成当前关闭，导入活动会按该设置结束；原始会话仍保留在导入原件。" }
            alert.addButton(withTitle:"恢复并保留原件");alert.addButton(withTitle:"取消")
            guard alert.runModal() == .alertFirstButtonReturn,canManageSave() else { return }
            let restored=try store.restore(data,currentState:engine.state)
            petView.cancelInteraction();cancelMovement();petScene?.discardSpeechStart();speech.hide();dialogue.resetTiming();autonomy.reset()
            engine=PetEngine(state:restored,catalog:catalog)
            engine.configureSimulation(enabled:simulationEnabled,fixedMood:fixedMood)
            state=engine.state;lastTick=nil;lastSave=ProcessInfo.processInfo.systemUptime
            restoreBaseAnimation(force:true)
            _=engine.drainEvents()
            guard save() else { message += " 新存档已恢复，但当前设置状态未能再次保存。";return }
            message="已恢复存档，活动状态遵循导入预览与当前养成设置。恢复前原件：\(store.lastRestoreBackupURL?.lastPathComponent ?? "存档目录")。"
        } catch { message="恢复失败，运行中的宠物保留：\(error.localizedDescription)" }
    }
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
