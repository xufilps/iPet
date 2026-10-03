// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
/// Draft-only selector: closing or cancelling never invokes onSave.
@MainActor final class PetMovementAreaWindow:NSWindow {
    init(frame:CGRect,minimum:CGFloat,onSave:@escaping (CGRect)->Void) {
        super.init(contentRect:frame,styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        title="选择桌宠移动范围";isReleasedWhenClosed=false;minSize=NSSize(width:max(300,minimum),height:max(180,minimum))
        setFrame(frame,display:false);level = .floating
        contentView=NSHostingView(rootView:AreaSelectionView(save:{ [weak self] in
            guard let self else { return };onSave(self.frame);self.close()
        },cancel:{ [weak self] in self?.close() }))
        backgroundColor=NSColor.windowBackgroundColor.withAlphaComponent(0.8);isOpaque=false
    }
}
private struct AreaSelectionView:View {
    let save:()->Void
    let cancel:()->Void
    var body:some View {
        VStack(spacing:12) {
            Text("拖动标题栏并缩放窗口，外框就是桌宠移动范围。").multilineTextAlignment(.center)
            Text("保存后按屏幕可见区域裁剪；取消不会改变现有范围。").font(.caption).foregroundStyle(.secondary)
            HStack { Button("取消",action:cancel).keyboardShortcut(.cancelAction);Button("使用此范围",action:save).keyboardShortcut(.defaultAction) }
        }.padding(20).frame(maxWidth:.infinity,maxHeight:.infinity)
    }
}
