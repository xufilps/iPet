import AppKit
import SwiftUI
import Combine
import SpriteKit
import PetCore
import PetRendering

@MainActor final class AppModel: ObservableObject {
    @Published var state = PetState()
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
    private var nextActivity = 0.0
    private var suspended = false
    private var observers: [NSObjectProtocol] = []
    private var menuVisibility: NSMenuItem!
    private var smokeMode: Bool { ProcessInfo.processInfo.environment["VPET_SMOKE_TEST"] == "1" }
    func start() throws {
        size = size.isFinite ? min(500, max(150, size)) : 280
        let base: URL
        if smokeMode { base = FileManager.default.temporaryDirectory.appendingPathComponent("VPet-smoke-\(ProcessInfo.processInfo.processIdentifier)") }
        else { base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("VPetApple") }
        store = PetSaveStore(directory: base)
        do { state = try store.load() ?? PetState(); message = store.recoveryMessage ?? "" }
        catch { writable = false; message = "\(error.localizedDescription) 本次仅运行，存档写入已暂停。" }
        engine = PetEngine(state: state)
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("PetAssets") else { throw PetSaveError.invalidDocument }
        petScene = PetScene(manifest: try PetManifest.load(from: root), assetRoot: root)
        petScene.play(state.resting ? .sleep : .idle, mood: state.mood)
        petScene.onDiagnostic = { text in NSLog("%@", text) }
        petScene.onActionFinished = { [weak self] _ in
            guard let self else { return }
            if self.state.resting { self.petScene.play(.sleep, mood: self.state.mood) }
        }
        petPanel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        petPanel.title = "VPet · 桌宠"
        petPanel.isOpaque = false; petPanel.backgroundColor = .clear; petPanel.hasShadow = false
        petPanel.level = .floating; petPanel.hidesOnDeactivate = false; petPanel.isReleasedWhenClosed = false
        petPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        petView = PetView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        petView.setAccessibilityLabel("萝莉斯桌宠")
        petView.allowsTransparency = true; petView.preferredFramesPerSecond = 30
        petView.autoresizingMask = [.width, .height]; petView.presentScene(petScene)
        petPanel.contentView = petView
        petView.onTouch = { [weak self] region in
            if region == "head" { self?.command(.touchHead) }
            else if region == "body" { self?.command(.touchBody) }
            else { self?.showControls() }
        }
        petView.onDragStart = { [weak self] in
            guard let self else { return }
            self.engine.recordInteraction()
            self.walkingUntil = 0; self.petScene.play(.raised, mood: self.state.mood)
        }
        petView.onDragEnd = { [weak self] in
            guard let self else { return }
            self.petScene.finishAction(); self.clampPosition(); self.persistPosition()
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
        lastSave = ProcessInfo.processInfo.systemUptime; nextActivity = lastSave + 20
        timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.tick() }
        if !message.isEmpty { showControls() }
        if smokeMode { startSmokeTest() }
    }
    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐾"
        statusItem.button?.toolTip = "VPet 原生桌宠"
        let menu = NSMenu()
        func item(_ title: String, _ selector: Selector) -> NSMenuItem { let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self; return item }
        menu.addItem(item("状态与设置…", #selector(showControls)))
        menu.addItem(item("投喂面包", #selector(feed))); menu.addItem(item("补充饮料", #selector(water)))
        menu.addItem(item("休息 / 起床", #selector(rest)))
        menuVisibility = item("隐藏桌宠", #selector(toggleVisibility)); menu.addItem(menuVisibility)
        menu.addItem(item("重置位置", #selector(resetPosition))); menu.addItem(.separator())
        menu.addItem(item("退出 VPet", #selector(quit))); statusItem.menu = menu
        let main = NSMenu(), appMenu = NSMenu()
        let preferences = item("状态与设置…", #selector(showControls)); preferences.keyEquivalent = ","
        let exit = item("退出 VPet", #selector(quit)); exit.keyEquivalent = "q"
        appMenu.addItem(preferences); appMenu.addItem(.separator()); appMenu.addItem(exit)
        let root = NSMenuItem(); root.submenu = appMenu; main.addItem(root); NSApp.mainMenu = main
    }
    func command(_ command: PetCommand) {
        walkingUntil = 0
        let action = engine.send(command); state = engine.state
        petScene.play(action, mood: state.mood); save()
    }
    @objc private func feed() { command(.feed) }
    @objc private func water() { command(.water) }
    @objc private func rest() { command(.toggleRest) }
    @objc private func quit() { NSApp.terminate(nil) }
    private func tick() {
        guard !suspended else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - (lastTick ?? now), 0), 0.1); lastTick = now
        engine.tick(); let oldMood = state.mood
        if state != engine.state { state = engine.state }
        if oldMood != state.mood && [.idle, .sleep].contains(petScene.requestedAction) { petScene.play(state.resting ? .sleep : .idle, mood: state.mood) }
        if visible {
            petPanel.ignoresMouseEvents = !petView.isInteracting && !petView.opaqueUnderMouse()
            if !petView.isInteracting && walkingUntil > now && autoMove {
                var origin = petPanel.frame.origin; origin.x += walkingDirection * 18 * delta
                petPanel.setFrameOrigin(origin); clampPosition()
            } else if walkingUntil > 0 { walkingUntil = 0; petScene.finishAction(); persistPosition() }
            if now >= nextActivity && !petView.isInteracting && petScene.requestedAction == .idle && !state.resting {
                nextActivity = now + Double.random(in: 25...50)
                if autoMove && state.mood != .ill {
                    walkingDirection = Bool.random() ? 1 : -1; walkingUntil = now + 5
                    petScene.play(walkingDirection > 0 ? .walkRight : .walkLeft, mood: state.mood)
                } else if state.strength < 70 { command(.toggleRest) }
            }
        }
        if now - lastSave >= 60 { save(); lastSave = now }
    }
    @objc func toggleVisibility() {
        visible.toggle(); menuVisibility.title = visible ? "隐藏桌宠" : "显示桌宠"
        walkingUntil = 0
        if visible { petScene.play(state.resting ? .sleep : .idle, mood: state.mood); petView.isPaused = false; petPanel.orderFrontRegardless() }
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
    private func suspend() { save(); suspended = true; walkingUntil = 0; petView.isPaused = true; petScene.releaseTextures() }
    private func resume() {
        engine.resetClock(); lastTick = nil; lastSave = ProcessInfo.processInfo.systemUptime
        nextActivity = lastSave + 20; suspended = false
        petScene.play(state.resting ? .sleep : .idle, mood: state.mood); petView.isPaused = !visible; clampPosition()
    }
    func save() {
        guard writable else { return }
        do { try store.save(engine.state) }
        catch { message = "保存失败：\(error.localizedDescription)"; NSLog("%@", message) }
    }
    func stop() { timer?.cancel(); if engine != nil { save() }; persistPositionIfReady() }
    private func persistPositionIfReady() { if petPanel != nil { persistPosition() } }
    @objc func showControls() {
        if controls == nil {
            let hosting = NSHostingController(rootView: ControlsView(model: self))
            let window = NSWindow(contentViewController: hosting); window.title = "VPet · 状态与设置"
            window.styleMask = [.titled, .closable]; window.isReleasedWhenClosed = false; window.center(); controls = window
        }
        NSApp.activate(ignoringOtherApps: true); controls?.makeKeyAndOrderFront(nil)
    }
    private func startSmokeTest() {
        // Isolated save path; exercise rendering, interruption, visibility and lifecycle without touching user saves.
        Task { @MainActor in
            for action in PetAction.allCases {
                petScene.play(action, mood: .normal)
                try? await Task.sleep(for: .milliseconds(350))
            }
            command(.feed); command(.water); command(.toggleRest)
            toggleVisibility(); toggleVisibility(); suspend(); resume()
            save(); showControls()
            NSLog("VPET_SMOKE_OK cacheBytes=%d state=%@", petScene.cacheBytes, state.mood.rawValue)
            if let raw = ProcessInfo.processInfo.environment["VPET_SOAK_SECONDS"], let seconds = Int(raw), seconds > 0 {
                let began = ProcessInfo.processInfo.systemUptime
                var index = 0
                while ProcessInfo.processInfo.systemUptime - began < Double(seconds) {
                    petScene.play(PetAction.allCases[index % PetAction.allCases.count], mood: PetMood.allCases[(index / PetAction.allCases.count) % PetMood.allCases.count])
                    if index % 10 == 0 { toggleVisibility(); toggleVisibility() }
                    if index % 20 == 0 { suspend(); resume() }
                    if index % 15 == 0 { NSLog("VPET_SOAK_SAMPLE cacheBytes=%d", petScene.cacheBytes) }
                    index += 1
                    try? await Task.sleep(for: .seconds(3))
                }
                NSLog("VPET_SOAK_DONE elapsed=%.1f cacheBytes=%d", ProcessInfo.processInfo.systemUptime - began, petScene.cacheBytes)
                NSApp.terminate(nil)
            }
        }
    }
}
