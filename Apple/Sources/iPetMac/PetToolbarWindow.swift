// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetCore
import PetRendering

enum ToolbarAction { case shortcut(Int),shortcuts, status,activity,shop,inventory,rest,talk,pauseOrResume,stop,close }
@MainActor private final class ToolbarPresentation:ObservableObject {
    @Published var shortcuts:[PetShortcutEntry]=[]
    @Published var name=""
    @Published var mood=""
    @Published var message=""
    @Published var resting=false
    @Published var feedback:ActivityFeedback?
}
private struct PetToolbarView:View {
    @ObservedObject var display:ToolbarPresentation
    let action:(ToolbarAction)->Void
    private let columns=[GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())]
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(display.name+" · "+display.mood).font(.caption).lineLimit(1)
                Spacer()
                Button { action(.close) } label: { Image(systemName:"xmark") }
                    .buttonStyle(.plain).accessibilityLabel("关闭随宠工具栏").help("关闭随宠工具栏")
            }
            LazyVGrid(columns:columns,spacing:6) {
                shortcut("状态",.status);shortcut("活动",.activity);shortcut("商店",.shop)
                shortcut("背包",.inventory);shortcut(display.resting ? "起床" : "休息",.rest);shortcut("聊一句",.talk)
                Menu("自定义") {
                    ForEach(display.shortcuts) { entry in Button(entry.name) { action(.shortcut(entry.id)) }.disabled(entry.kind == .windowsKeys) }
                    if !display.shortcuts.isEmpty { Divider() }
                    Button("管理快捷入口…") { action(.shortcuts) }
                }.frame(maxWidth:.infinity)
            }
            if let feedback=display.feedback {
                Divider()
                Text(feedback.title+(feedback.isPaused ? " · 已暂停" : " · 进行中")).font(.caption.bold()).lineLimit(2)
                if let progress=feedback.progress,let remaining=feedback.remainingSeconds {
                    ProgressView(value:progress)
                    Text("剩余 \(Int(ceil(remaining/60))) 分钟 · 已获 \(feedback.earned.formatted(.number.precision(.fractionLength(2)))) \(feedback.unit)")
                        .font(.caption).monospacedDigit().fixedSize(horizontal:false,vertical:true)
                } else { Text("已获 \(feedback.earned.formatted(.number.precision(.fractionLength(2)))) \(feedback.unit)").font(.caption) }
                HStack {
                    Button(feedback.isPaused ? "继续" : "暂停") { action(.pauseOrResume) }.disabled(feedback.isPaused && !feedback.canResume)
                    Button("结束") { action(.stop) }.help("提前结束保留已获收益，不追加完成奖励")
                }
            }
            if !display.message.isEmpty { Text(display.message).font(.caption).foregroundStyle(.secondary).lineLimit(3).help(display.message) }
        }.padding(10).frame(width:264)
            .background(Color(nsColor:.windowBackgroundColor).opacity(0.97),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(Color.primary.opacity(0.12),lineWidth:1))
    }
    private func shortcut(_ title:String,_ kind:ToolbarAction) -> some View {
        Button(title) { action(kind) }.frame(maxWidth:.infinity)
    }
}
@MainActor private final class ToolbarHostingView:NSHostingView<PetToolbarView> {
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
}
@MainActor final class PetToolbarWindow {
    private let panel=PetPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
    private let display=ToolbarPresentation()
    private var hosting:NSHostingView<PetToolbarView>!
    var visibleFrame:CGRect? { panel.isVisible ? panel.frame : nil }
    func setTopMost(_ value:Bool) { panel.level=value ? .floating:.normal }
    init(action:@escaping (ToolbarAction)->Void) {
        panel.title="iPet · 快捷工具栏";panel.isOpaque=false;panel.backgroundColor = .clear
        panel.hasShadow=true;panel.level = .floating;panel.hidesOnDeactivate=false
        panel.isReleasedWhenClosed=false;panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        hosting=ToolbarHostingView(rootView:PetToolbarView(display:display,action:action));panel.contentView=hosting
    }
    func update(state:PetState,catalog:PetCatalog,message:String,shortcuts:[PetShortcutEntry]=[],petFrame:CGRect,screen:CGRect) {
        display.name=state.name;display.mood=state.resting ? "休息中" : state.mood.title
        display.resting=state.resting;display.message=message;display.shortcuts=shortcuts
        display.feedback=state.activity.map { ActivityFeedback(session:$0,activity:catalog.activity($0.activityID),mood:state.mood) }
        hosting.layoutSubtreeIfNeeded()
        let frame=SpeechPlacement.frame(pet:petFrame,bubble:hosting.fittingSize,screen:screen,preferBelow:true)
        if panel.frame != frame { panel.setFrame(frame,display:true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
    func hide() { panel.orderOut(nil) }
}
