// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import AppKit
import SpriteKit
import PetRendering
import PetCore

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor final class PetView: SKView {
    var onPanelRequested:(() -> Void)?
    var onPressBegin: (() -> Void)?
    var canLift: ((CGPoint) -> Bool)?
    var onTouch: ((String?) -> Void)?
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onDragMotion: ((Double) -> Void)?
    private var lastDragPoint:NSPoint?
    private var origin: NSPoint?
    private var mouseOrigin: NSPoint?
    private var gesture = PetPointerGesture()
    private var pressTask: Task<Void,Never>?
    private var lastViewPoint: CGPoint?
    var isDragging: Bool { gesture.isLifted }
    var isInteracting: Bool { gesture.isPressed }
    private var petScene: PetScene? { scene as? PetScene }
    func scenePoint(_ viewPoint: CGPoint) -> CGPoint { scene?.convertPoint(fromView: viewPoint) ?? .zero }
    func opaqueUnderMouse() -> Bool {
        guard let window else { return false }
        let local = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        return bounds.contains(local) && petScene?.isOpaque(at: scenePoint(local)) == true
    }
    private func logInput(_ event: NSEvent) {
        if ProcessInfo.processInfo.environment["IPET_MANUAL_TEST"] == "1" {
            NSLog("IPET_MOUSE type=%d local=(%.1f,%.1f) cursor=(%.1f,%.1f)",event.type.rawValue,event.locationInWindow.x,event.locationInWindow.y,NSEvent.mouseLocation.x,NSEvent.mouseLocation.y)
        }
    }
    private func checkLongPress() {
        let allowed=lastViewPoint.map { canLift?(scenePoint($0)) == true } ?? false
        if gesture.poll(time:ProcessInfo.processInfo.systemUptime,canLift:allowed) { onDragStart?() }
    }
    func cancelInteraction() {
        pressTask?.cancel();pressTask=nil
        let lifted=gesture.isLifted
        gesture.cancel();origin=nil;mouseOrigin=nil;lastViewPoint=nil;lastDragPoint=nil
        if lifted { onDragEnd?() }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { cancelInteraction() }
    }
    override func mouseDown(with event: NSEvent) {
        logInput(event);cancelInteraction()
        guard let window else { return }
        origin=window.frame.origin;mouseOrigin=window.convertPoint(toScreen:event.locationInWindow);lastDragPoint=mouseOrigin
        lastViewPoint=convert(event.locationInWindow,from:nil)
        gesture.begin(x:Double(mouseOrigin!.x),y:Double(mouseOrigin!.y),time:ProcessInfo.processInfo.systemUptime)
        onPressBegin?()
        pressTask=Task { @MainActor [weak self] in
            do { try await Task.sleep(for:.milliseconds(300)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.checkLongPress()
        }
    }
    override func mouseDragged(with event: NSEvent) {
        logInput(event)
        guard let origin, let mouseOrigin, let window, gesture.isPressed else { return }
        lastViewPoint=convert(event.locationInWindow,from:nil)
        let current=window.convertPoint(toScreen:event.locationInWindow)
        if gesture.move(x:Double(current.x),y:Double(current.y)) { pressTask?.cancel();onDragStart?() }
        if gesture.isLifted,let previous=lastDragPoint {
            onDragMotion?((abs(current.x-previous.x)+abs(current.y-previous.y))*500/max(1,window.frame.width))
        }
        lastDragPoint=current
        if gesture.isLifted { window.setFrameOrigin(NSPoint(x:origin.x+current.x-mouseOrigin.x,y:origin.y+current.y-mouseOrigin.y)) }
    }
    override func mouseUp(with event: NSEvent) {
        logInput(event)
        lastViewPoint=convert(event.locationInWindow,from:nil)
        checkLongPress();pressTask?.cancel();pressTask=nil
        let released=gesture.release()
        origin=nil;mouseOrigin=nil;lastViewPoint=nil;lastDragPoint=nil
        switch released {
        case .drop: onDragEnd?()
        case .tap: onTouch?(petScene?.region(at:scenePoint(convert(event.locationInWindow,from:nil))))
        case .none: break
        }
    }
    override func rightMouseDown(with event: NSEvent) { cancelInteraction();onPanelRequested?() }
}
