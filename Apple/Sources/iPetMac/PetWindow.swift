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
    override func mouseDown(with event: NSEvent) {
        origin = window?.frame.origin; mouseOrigin = NSEvent.mouseLocation; dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let origin, let mouseOrigin else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - mouseOrigin.x, dy = current.y - mouseOrigin.y
        if !dragging && hypot(dx, dy) > 4 { dragging = true; onDragStart?() }
        if dragging { window?.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy)) }
    }
    override func mouseUp(with event: NSEvent) {
        defer { dragging = false; origin = nil; mouseOrigin = nil }
        if dragging { onDragEnd?() }
        else { onTouch?(petScene?.region(at: scenePoint(convert(event.locationInWindow, from: nil)))) }
    }
    override func rightMouseDown(with event: NSEvent) { onTouch?(nil) }
}
