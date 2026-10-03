// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import UIKit
import SpriteKit
import PetRendering

struct PetStageView: UIViewRepresentable {
    let scene: PetScene
    let active: Bool
    let onTouch: (CGPoint)->Void
    func makeCoordinator() -> Coordinator { Coordinator(onTouch:onTouch) }
    func makeUIView(context:Context) -> SKView {
        let view=SKView()
        view.backgroundColor = .clear;view.isOpaque=false;view.allowsTransparency=true
        view.preferredFramesPerSecond=30;view.ignoresSiblingOrder=true
        scene.resetTiming();view.presentScene(scene);view.isPaused = !active
        let tap=UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.tap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ view:SKView,context:Context) {
        context.coordinator.onTouch=onTouch
        view.isPaused = !active
        if view.scene !== scene { view.presentScene(scene) }
        scene.setTextureResolution(pixelWidth:640)
    }
    static func dismantleUIView(_ view:SKView,coordinator:Coordinator) { view.presentScene(nil) }
    @MainActor final class Coordinator: NSObject {
        var onTouch:(CGPoint)->Void
        init(onTouch:@escaping (CGPoint)->Void) { self.onTouch=onTouch }
        @objc func tap(_ recognizer:UITapGestureRecognizer) {
            guard let view=recognizer.view as? SKView,let scene=view.scene else { return }
            onTouch(scene.convertPoint(fromView:recognizer.location(in:view)))
        }
    }
}
