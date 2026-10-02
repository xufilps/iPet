// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import AppKit
import SpriteKit
import PetRendering

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor final class PetView: SKView {
    var onTouch: ((String?) -> Void)?
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    private var origin: NSPoint?
    private var mouseOrigin: NSPoint?
    private var dragging = false
    var isDragging: Bool { dragging }
    var isInteracting: Bool { mouseOrigin != nil }
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
    override func mouseDown(with event: NSEvent) {
        logInput(event)
        origin = window?.frame.origin; mouseOrigin = window?.convertPoint(toScreen:event.locationInWindow); dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        logInput(event)
        guard let origin, let mouseOrigin, let window else { return }
        // Event coordinates stay correct for queued/coalesced and directed input.
        let current = window.convertPoint(toScreen:event.locationInWindow)
        let dx = current.x - mouseOrigin.x, dy = current.y - mouseOrigin.y
        if !dragging && hypot(dx, dy) > 4 { dragging = true; onDragStart?() }
        if dragging { window.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy)) }
    }
    override func mouseUp(with event: NSEvent) {
        logInput(event)
        defer { dragging = false; origin = nil; mouseOrigin = nil }
        if dragging { onDragEnd?() }
        else { onTouch?(petScene?.region(at: scenePoint(convert(event.locationInWindow, from: nil)))) }
    }
    override func rightMouseDown(with event: NSEvent) { onTouch?(nil) }
}
