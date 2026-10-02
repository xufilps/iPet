// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetRendering

private struct SpeechBubble:View {
    let text:String
    var body:some View {
        Text(text).font(.system(size:15)).foregroundStyle(.primary)
            .fixedSize(horizontal:false,vertical:true).frame(width:240,alignment:.leading).padding(12)
            .background(Color(nsColor:.windowBackgroundColor).opacity(0.96),in:RoundedRectangle(cornerRadius:14))
            .overlay(RoundedRectangle(cornerRadius:14).stroke(Color.primary.opacity(0.12),lineWidth:1))
            .accessibilityLabel("桌宠说话："+text)
    }
}
@MainActor final class PetSpeechWindow {
    private let panel=PetPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
    private var contentSize=CGSize.zero
    var isVisible:Bool { panel.isVisible }
    init() {
        panel.title="iPet · 说话";panel.isOpaque=false;panel.backgroundColor = .clear
        panel.hasShadow=true;panel.level = .floating;panel.hidesOnDeactivate=false
        panel.ignoresMouseEvents=true;panel.isReleasedWhenClosed=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
    }
    func show(text:String,petFrame:CGRect,screen:CGRect) {
        let view=NSHostingView(rootView:SpeechBubble(text:text))
        panel.contentView=view;contentSize=view.fittingSize
        updatePosition(petFrame:petFrame,screen:screen);panel.orderFrontRegardless()
        if ProcessInfo.processInfo.environment["IPET_MANUAL_TEST"] == "1" {
            NSLog("IPET_SPEECH visible=%d width=%.1f height=%.1f key=%d ignoresMouse=%d",panel.isVisible ? 1 : 0,panel.frame.width,panel.frame.height,panel.isKeyWindow ? 1 : 0,panel.ignoresMouseEvents ? 1 : 0)
        }
    }
    func updatePosition(petFrame:CGRect,screen:CGRect) {
        guard !screen.isEmpty else { hide();return }
        let frame=SpeechPlacement.frame(pet:petFrame,bubble:contentSize,screen:screen)
        if panel.frame != frame { panel.setFrame(frame,display:true) }
    }
    func hide() { panel.orderOut(nil) }
}
