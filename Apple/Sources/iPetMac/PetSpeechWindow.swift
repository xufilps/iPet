// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import Combine
import PetCore
import PetRendering

@MainActor private final class SpeechTextModel:ObservableObject {
    @Published var text=""
    var fullText=""
    var name=""
}
private struct SpeechBubble:View {
    @ObservedObject var content:SpeechTextModel
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            Text(content.name).font(.system(size:12,weight:.semibold)).foregroundStyle(.secondary)
            ZStack(alignment:.topLeading) {
                Text(content.fullText).hidden()
                Text(content.text)
            }.font(.system(size:15)).foregroundStyle(.primary)
                .fixedSize(horizontal:false,vertical:true).frame(width:240,alignment:.leading)
        }.padding(12)
            .background(Color(nsColor:.windowBackgroundColor),in:RoundedRectangle(cornerRadius:14))
            .overlay(RoundedRectangle(cornerRadius:14).stroke(Color.primary.opacity(0.12),lineWidth:1))
            .accessibilityElement(children:.ignore)
            .accessibilityLabel(content.name+"说："+content.fullText)
    }
}
@MainActor private final class SpeechHostingView:NSHostingView<SpeechBubble>,NSMenuDelegate {
    var onClose:(()->Void)?
    var onCopy:(()->Void)?
    var onMenuChanged:(()->Void)?
    private(set) var menuTracking=false
    override func mouseDown(with event:NSEvent) { if event.clickCount>=2 { onClose?() } }
    override func rightMouseDown(with event:NSEvent) {
        let menu=NSMenu();menu.delegate=self
        for (title,action) in [("复制已显示文字",#selector(copySpeech)),("关闭说话",#selector(closeSpeech))] {
            let item=NSMenuItem(title:title,action:action,keyEquivalent:"");item.target=self;menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu,with:event,for:self)
    }
    @objc private func copySpeech() { onCopy?() }
    @objc private func closeSpeech() { onClose?() }
    func menuWillOpen(_ menu:NSMenu) { menuTracking=true;onMenuChanged?() }
    func menuDidClose(_ menu:NSMenu) { menuTracking=false;onMenuChanged?() }
}
@MainActor final class PetSpeechWindow {
    private let panel=PetPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
    private let content=SpeechTextModel()
    private var playback:PetSpeechPlayback?
    private var previousTime:TimeInterval?
    private var contentSize=CGSize.zero
    private var interactive=false
    private var hosting:SpeechHostingView?
    var onCloseRequested:(()->Void)?
    var onRevealFinished:(()->Void)?
    var isVisible:Bool { panel.isVisible }
    func setInteractive(_ value:Bool) { interactive=value;updateInteraction() }
    private var mouseInside:Bool {
        let point=panel.convertPoint(fromScreen:NSEvent.mouseLocation)
        return NSBezierPath(roundedRect:CGRect(origin:.zero,size:panel.frame.size),xRadius:14,yRadius:14).contains(point)
    }
    private func updateInteraction() {
        let hovered=interactive && (mouseInside || hosting?.menuTracking == true)
        playback?.setHovered(hovered)
        panel.ignoresMouseEvents = !interactive || !mouseInside
    }
    func setTopMost(_ value:Bool) { panel.level=value ? .floating:.normal }
    init() {
        panel.title="iPet · 说话";panel.isOpaque=false;panel.backgroundColor = .clear
        panel.hasShadow=true;panel.level = .floating;panel.hidesOnDeactivate=false
        panel.ignoresMouseEvents=true;panel.isReleasedWhenClosed=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
    }
    func show(text:String,name:String,petFrame:CGRect,screen:CGRect) {
        let next=PetSpeechPlayback(text:text)
        playback=next;previousTime=ProcessInfo.processInfo.systemUptime
        content.text="";content.fullText=next.fullText;content.name=name
        let view=SpeechHostingView(rootView:SpeechBubble(content:content))
        view.onClose={ [weak self] in self?.onCloseRequested?() }
        view.onCopy={ [weak self] in
            guard let self else { return };NSPasteboard.general.clearContents();NSPasteboard.general.setString(self.content.text,forType:.string)
        }
        view.onMenuChanged={ [weak self] in self?.updateInteraction() }
        hosting=view;panel.contentView=view;contentSize=view.fittingSize;panel.alphaValue=next.opacity
        updatePosition(petFrame:petFrame,screen:screen);panel.orderFrontRegardless();updateInteraction()
        if ProcessInfo.processInfo.environment["IPET_MANUAL_TEST"] == "1" {
            NSLog("IPET_SPEECH visible=%d width=%.1f height=%.1f key=%d ignoresMouse=%d",panel.isVisible ? 1 : 0,panel.frame.width,panel.frame.height,panel.isKeyWindow ? 1 : 0,panel.ignoresMouseEvents ? 1 : 0)
        }
    }
    func advance(to time:TimeInterval) {
        updateInteraction()
        guard time.isFinite,let previousTime,time>=previousTime,var playback else { return }
        self.previousTime=time;let revealed=playback.advance(by:time-previousTime);self.playback=playback
        if revealed { onRevealFinished?() }
        if playback.phase == .finished { hide();return }
        let text=playback.displayedText
        if content.text != text { content.text=text }
        panel.alphaValue=playback.opacity
    }
    func updatePosition(petFrame:CGRect,screen:CGRect) {
        guard !screen.isEmpty else { hide();return }
        let frame=SpeechPlacement.frame(pet:petFrame,bubble:contentSize,screen:screen)
        if panel.frame != frame { panel.setFrame(frame,display:true) }
    }
    func hide() { playback?.cancel();playback=nil;previousTime=nil;panel.orderOut(nil) }
}
