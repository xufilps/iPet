// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import Combine
import SpriteKit
import PetCore
import PetRendering

enum ControlPage: String, CaseIterable { case status="状态", activity="活动", shop="商店", inventory="背包", settings="设置" }

@MainActor final class AppModel: ObservableObject {
    @Published var state = PetState()
    @Published var selectedPage = ControlPage.status
    private(set) var catalog = PetCatalog()
    private(set) var assetRoot: URL!
    private var lastUIRefresh = 0.0
    @Published var message = ""
    @Published var size = UserDefaults.standard.object(forKey: "petSize") as? Double ?? 280
    @Published var autoMove = UserDefaults.standard.object(forKey: "autoMove") as? Bool ?? true
    @Published var visible = true
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
    private var walkingUntil = 0.0
    private var walkingDirection = 1.0
    private let autonomy = PetAutonomy()
    private var dialogue:PetDialogue!
    private let speech=PetSpeechWindow()
    private var speechUntil=0.0
    private var autonomousUntil = 0.0
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
    }
    func start() throws {
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
        dialogue=PetDialogue(catalog:try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json")))
        petScene = PetScene(manifest: try PetManifest.load(from: root), assetRoot: root)
        petScene.play(state.resting ? .sleep : .idle, mood: state.mood)
        petScene.onIdleCycle = { [weak self] in self?.autonomy.recordIdleCycle() }
        petScene.onDiagnostic = { text in NSLog("%@", text) }
        petScene.onActionFinished = { [weak self] _ in
            guard let self else { return }
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
        petView.canLift = { [weak self] point in
            guard let self else { return false }
            return self.petScene.canRaise(at:point,mood:self.engine.state.mood)
        }
        petView.onTouch = { [weak self] region in
            self?.recordAcceptanceInput("touch:\(region ?? "panel")")
            if region == "head" { self?.command(.touchHead) }
            else if region == "body" { self?.command(.touchBody) }
            else { self?.sayClick() }
        }
        petView.onDragStart = { [weak self] in
            guard let self else { return }
            self.recordAcceptanceInput("drag-start")
            self.engine.recordInteraction(); self.autonomy.reset(); self.autonomousUntil = 0
            self.walkingUntil = 0; self.petScene.play(.raised, mood: self.state.mood)
        }
        petView.onDragEnd = { [weak self] in
            guard let self else { return }
            self.petScene.finishAction(); self.clampPosition(); self.persistPosition()
            self.recordAcceptanceInput("drag-end")
        }
        if let x = UserDefaults.standard.object(forKey: "petX") as? Double, let y = UserDefaults.standard.object(forKey: "petY") as? Double {
            petPanel.setFrameOrigin(NSPoint(x: x, y: y)); clampPosition()
        } else { resetPosition() }
        petPanel.orderFrontRegardless()
        updateTextureResolution()
        buildMenu()
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.suspend() } })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.resume() } })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.clampPosition(); self?.updateTextureResolution() } })
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
        menu.addItem(item("聊一句", #selector(sayClick)))
        menu.addItem(item("休息 / 起床", #selector(rest)))
        menuVisibility = item("隐藏桌宠", #selector(toggleVisibility)); menu.addItem(menuVisibility)
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
    func command(_ command: PetCommand) {
        petView.cancelInteraction()
        walkingUntil = 0; autonomousUntil = 0; autonomy.reset()
        let action = engine.send(command); state = engine.state
        consumeEvents()
        if !petScene.isFinishingActivity || ![.idle,.sleep].contains(action) {
            if [.head,.body].contains(action) { petScene.playTouch(action,mood:state.mood) }
            else { petScene.play(action,mood:state.mood) }
        }
        save()
    }
    func perform(_ command: PetEconomyCommand) {
        let result = engine.perform(command)
        state = engine.state; message = result.message
        if result.accepted {
            petView.cancelInteraction()
            walkingUntil = 0; autonomousUntil = 0; autonomy.reset()
            let usedItem = consumeEvents()
            if !usedItem { restoreBaseAnimation() }
            save()
        }
    }
    func itemMultiplier(id: String) -> Double {
        guard let item=catalog.item(id) else { return 0 }
        return PetItemRules.multiplier(category:item.category,expiry:state.itemCooldowns[id],now:Date())
    }
    @discardableResult private func consumeEvents() -> Bool {
        var usedItem = false, stopped = false
        for event in engine.drainEvents() {
            switch event {
            case let .activityStopped(id, reason, earned, bonus):
                stopped = true
                let title=catalog.activity(id)?.name ?? id
                let unit=catalog.activity(id)?.kind == .work ? "金币" : "经验"
                let reasonText=reason == .completed ? "完成" : reason == .manual ? "结束" : "因状态不佳停止"
                message="\(title)\(reasonText)，已获\(earned.formatted(.number.precision(.fractionLength(2))))\(unit)，完成奖励\(bonus.formatted(.number.precision(.fractionLength(2))))。"
            case let .itemUsed(id):
                if let item=catalog.item(id) {
                    usedItem = true
                    petScene.setFoodImage(path:item.imagePath)
                    let action: PetAction = item.graphID.lowercased() == "drink" ? .drink : item.graphID.lowercased() == "gift" ? .gift : .eat
                    petScene.play(action,mood:engine.state.mood)
                }
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
        guard petScene != nil, petView?.isInteracting != true else { return }
        if petScene.restoreBase(state:engine.state,catalog:catalog,force:force) { autonomousUntil = 0 }
    }
    @objc private func showActivities() { selectedPage = .activity; showControls() }
    @objc private func showShop() { selectedPage = .shop; showControls() }
    @objc private func showInventory() { selectedPage = .inventory; showControls() }
    @objc func sayClick() {
        guard visible, !suspended else { message="请先显示桌宠，再聊一句。";return }
        guard let entry=dialogue.click(state:engine.state,gameplay:catalog,hour:Calendar.current.component(.hour,from:Date())) else { return }
        let oldMood=engine.state.mood
        guard engine.applyDialogue(entry.effects) else { message="本地文本效果不合法，未应用。";return }
        state=engine.state;autonomy.reset();consumeEvents();save()
        if oldMood != state.mood {
            if !petScene.playMoodTransition(from:oldMood,to:state.mood) && [.idle,.sleep,.activity].contains(petScene.requestedAction) { restoreBaseAnimation() }
        }
        showSpeech(entry.rendered(state:state))
    }
    private func showSpeech(_ text:String) {
        guard visible, !suspended, let screen=petPanel.screen ?? NSScreen.main else { return }
        speech.show(text:text,petFrame:petPanel.frame,screen:screen.visibleFrame)
        speechUntil=ProcessInfo.processInfo.systemUptime+max(5,min(14,Double(text.count)*0.08))
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
            else if let screen=petPanel.screen ?? NSScreen.main { speech.updatePosition(petFrame:petPanel.frame,screen:screen.visibleFrame) }
        }
        let oldMood = engine.state.mood
        engine.tick()
        consumeEvents()
        if now - lastUIRefresh >= 0.25 { state = engine.state; lastUIRefresh = now }
        if oldMood != engine.state.mood {
            if !petScene.playMoodTransition(from:oldMood,to:engine.state.mood) && [.idle,.sleep,.activity].contains(petScene.requestedAction) { restoreBaseAnimation() }
        }
        if visible {
            petPanel.ignoresMouseEvents = !petView.isInteracting && !petView.opaqueUnderMouse()
            if !petView.isInteracting && walkingUntil > now && autoMove {
                var origin = petPanel.frame.origin; origin.x += walkingDirection * 18 * delta
                petPanel.setFrameOrigin(origin); clampPosition()
            } else if walkingUntil > 0 { walkingUntil = 0; petScene.finishAction(); persistPosition() }
        }
        if autonomousUntil > 0 && now >= autonomousUntil {
            autonomousUntil = 0; petScene.finishAction()
        }
        let eligible = !manualTest && PetAutonomy.canStart(state:engine.state,action:petScene.requestedAction,visible:visible,interacting:petView.isInteracting,finishing:petScene.isFinishingActivity)
        if let entry=dialogue.automatic(state:engine.state,eligible:eligible && !speech.isVisible) { showSpeech(entry.rendered(state:engine.state)) }
        if let behavior = autonomy.poll(eligible:eligible,allowsMovement:autoMove,mood:engine.state.mood) {
            switch behavior {
            case .walkLeft, .walkRight:
                walkingDirection = behavior == .walkRight ? 1 : -1;walkingUntil=now+5
                petScene.play(behavior == .walkRight ? .walkRight : .walkLeft,mood:engine.state.mood)
            case .fidget:
                petScene.playFidget(graphID:autonomy.fidgetGraphID,mood:engine.state.mood)
            case .doze:
                autonomousUntil=now+20;petScene.play(.sleep,mood:engine.state.mood)
            }
        }
        if now - lastSave >= 60 { save(); lastSave = now }
    }
    @objc func toggleVisibility() {
        petView.cancelInteraction()
        speech.hide();dialogue.resetTiming()
        visible.toggle(); menuVisibility.title = visible ? "隐藏桌宠" : "显示桌宠"
        walkingUntil = 0; autonomousUntil = 0; autonomy.reset()
        if visible { restoreBaseAnimation(force:true); petView.isPaused = false; petPanel.orderFrontRegardless() }
        else { petPanel.orderOut(nil); petView.isPaused = true; petScene.releaseTextures() }
    }
    func updateSize() {
        size = min(500, max(150, size)); if !smokeMode { UserDefaults.standard.set(size, forKey: "petSize") }
        petPanel.setContentSize(NSSize(width: size, height: size)); clampPosition(); updateTextureResolution()
    }
    private func updateTextureResolution() {
        petScene.setTextureResolution(pixelWidth: Int(size * (petPanel.screen?.backingScaleFactor ?? 2)))
    }
    func updateAutoMove() {
        if !smokeMode { UserDefaults.standard.set(autoMove, forKey: "autoMove") }
        if !autoMove && walkingUntil > 0 { walkingUntil = 0; petScene.finishAction() }
    }
    @objc func resetPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        petPanel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - size - 30, y: screen.visibleFrame.minY + 30)); persistPosition()
    }
    private func clampPosition() {
        guard let screen = NSScreen.screens.max(by: { intersectionArea($0.visibleFrame) < intersectionArea($1.visibleFrame) }) else { return }
        let visible = screen.visibleFrame, frame = petPanel.frame
        petPanel.setFrameOrigin(NSPoint(x: min(max(frame.minX, visible.minX), max(visible.minX, visible.maxX - frame.width)), y: min(max(frame.minY, visible.minY), max(visible.minY, visible.maxY - frame.height))))
    }
    private func intersectionArea(_ rect: NSRect) -> CGFloat { let overlap = rect.intersection(petPanel.frame); return overlap.isNull ? 0 : overlap.width * overlap.height }
    private func persistPosition() {
        guard !smokeMode else { return }
        UserDefaults.standard.set(petPanel.frame.minX, forKey: "petX"); UserDefaults.standard.set(petPanel.frame.minY, forKey: "petY")
    }
    private func suspend() { petView.cancelInteraction();speech.hide();dialogue.resetTiming();save(); suspended = true; walkingUntil = 0; autonomousUntil = 0; autonomy.reset(); petView.isPaused = true; petScene.releaseTextures() }
    private func resume() {
        engine.resetClock();dialogue.resetTiming(); lastTick = nil; lastSave = ProcessInfo.processInfo.systemUptime
        autonomousUntil = 0; autonomy.reset(); suspended = false
        restoreBaseAnimation(force:true); petView.isPaused = !visible; clampPosition()
    }
    func save() {
        guard writable else { return }
        do { try store.save(engine.state) }
        catch { message = "保存失败：\(error.localizedDescription)"; NSLog("%@", message) }
    }
    func stop() { speech.hide();petView?.cancelInteraction();timer?.cancel(); if engine != nil { save() }; persistPositionIfReady() }
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
