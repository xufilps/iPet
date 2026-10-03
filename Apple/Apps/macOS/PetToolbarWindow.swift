// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetCore
import PetRendering

enum ToolbarAction { case startActivity(String),shortcut(Int),stopKeyboard,shortcuts, status,activity,shop,inventory,rest,talk,pauseOrResume,stop,close }
@MainActor private final class ToolbarPresentation:ObservableObject {
    @Published var shortcuts:[PetShortcutEntry]=[]
    @Published var activities:[PetActivityMenuItem]=[]
    @Published var name=""
    @Published var mood=""
    @Published var message=""
    @Published var growthNotice=""
    @Published var resting=false
    @Published var feedback:ActivityFeedback?
}
private struct PetToolbarView:View {
    @State private var timerMode=PetActivityTimerMode.elapsed
    @ObservedObject var display:ToolbarPresentation
    let action:(ToolbarAction)->Void
    let hoverChanged:(Bool)->Void
    let menuChanged:(Bool)->Void
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
                shortcut("状态",.status)
                Menu("活动") {
                    ForEach(ActivityKind.allCases,id:\.self) { kind in
                        let choices=display.activities.filter { $0.kind == kind }
                        if !choices.isEmpty {
                            Section(kind.title) {
                                ForEach(choices) { item in
                                    Button(item.name+(item.isCurrent ? " · 停止当前活动":" · 等级\(item.levelLimit)+")) { action(.startActivity(item.id)) }
                                        .disabled(!item.isEnabled)
                                }
                            }
                        }
                    }
                    Divider()
                    Button("活动面板与倍率…") { action(.activity) }
                }.frame(maxWidth:.infinity)
                shortcut("商店",.shop)
                shortcut("背包",.inventory);shortcut(display.resting ? "起床" : "休息",.rest);shortcut("聊一句",.talk)
                Menu("自定义") {
                    ForEach(display.shortcuts) { entry in Button(entry.name) { action(.shortcut(entry.id)) }.disabled(entry.kind == .windowsKeys) }
                    if !display.shortcuts.isEmpty { Divider() }
                    Button("停止剩余按键") { action(.stopKeyboard) }
                    Button("管理快捷入口…") { action(.shortcuts) }
                }.frame(maxWidth:.infinity)
            }
            if let feedback=display.feedback {
                Divider()
                Text(feedback.title+(feedback.isPaused ? " · 已暂停" : " · 进行中")).font(.caption.bold()).lineLimit(2)
                Button("显示："+timerMode.title) { timerMode=timerMode.next }
                    .font(.caption).help("依次切换已用时间、剩余时间、累计收益和收起详情")
                    .accessibilityLabel("切换活动计时显示，当前"+timerMode.title)
                if let readout=PetActivityTimer.readout(feedback:feedback,mode:timerMode) {
                    if let progress=feedback.progress { ProgressView(value:progress) }
                    Text(readout.value+" "+readout.unit).font(.caption).monospacedDigit()
                        .fixedSize(horizontal:false,vertical:true)
                }
                HStack {
                    Button(feedback.isPaused ? "继续" : "暂停") { action(.pauseOrResume) }.disabled(feedback.isPaused && !feedback.canResume)
                    Button("结束") { action(.stop) }.help("提前结束保留已获收益，不追加完成奖励")
                }
            }
            if !display.growthNotice.isEmpty { Text(display.growthNotice).font(.caption).lineLimit(3).help(display.growthNotice) }
            if !display.message.isEmpty { Text(display.message).font(.caption).foregroundStyle(.secondary).lineLimit(3).help(display.message) }
        }.padding(10).frame(width:264)
            .background(Color(nsColor:.windowBackgroundColor).opacity(0.97),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(Color.primary.opacity(0.12),lineWidth:1))
            .onHover(perform:hoverChanged)
            .onReceive(NotificationCenter.default.publisher(for:NSMenu.didBeginTrackingNotification)) { _ in menuChanged(true) }
            .onReceive(NotificationCenter.default.publisher(for:NSMenu.didEndTrackingNotification)) { _ in menuChanged(false) }
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
    private var visibility=PetToolbarVisibility()
    private var autoHideEnabled=false
    private var hovered=false
    private var menuTracking=false
    var visibleFrame:CGRect? { panel.isVisible ? panel.frame : nil }
    func setTopMost(_ value:Bool) { panel.level=value ? .floating:.normal }
    init(action:@escaping (ToolbarAction)->Void) {
        panel.title="iPet · 快捷工具栏";panel.isOpaque=false;panel.backgroundColor = .clear
        panel.hasShadow=true;panel.level = .floating;panel.hidesOnDeactivate=false
        panel.isReleasedWhenClosed=false;panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        hosting=ToolbarHostingView(rootView:PetToolbarView(display:display,action:action,
            hoverChanged:{ [weak self] in self?.interactionChanged(hovered:$0) },
            menuChanged:{ [weak self] in self?.interactionChanged(menuTracking:$0) }));panel.contentView=hosting
    }
    func update(state:PetState,catalog:PetCatalog,message:String,growthNotice:String="",activitiesEnabled:Bool=true,autoHide:Bool=false,shortcuts:[PetShortcutEntry]=[],petFrame:CGRect,screen:CGRect) {
        autoHideEnabled=autoHide
        display.name=state.name;display.mood=state.resting ? "休息中" : state.mood.title
        display.activities=PetActivityMenu.items(catalog:catalog,state:state,enabled:activitiesEnabled)
        display.resting=state.resting;display.message=message;display.growthNotice=growthNotice;display.shortcuts=shortcuts
        display.feedback=state.activity.map { ActivityFeedback(session:$0,activity:catalog.activity($0.activityID),mood:state.mood) }
        hosting.layoutSubtreeIfNeeded()
        let frame=SpeechPlacement.frame(pet:petFrame,bubble:hosting.fittingSize,screen:screen,preferBelow:true)
        if panel.frame != frame { panel.setFrame(frame,display:true) }
        let pointer=NSEvent.mouseLocation
        let overToolbar=panel.isVisible && (hovered || panel.frame.contains(pointer))
        let show=visibility.update(now:ProcessInfo.processInfo.systemUptime,autoHide:autoHide,
                                   hovered:petFrame.contains(pointer) || overToolbar,menuTracking:menuTracking)
        if show { if !panel.isVisible { panel.orderFrontRegardless() } }
        else { panel.orderOut(nil);hovered=false }
    }
    private func interactionChanged(hovered:Bool?=nil,menuTracking:Bool?=nil) {
        if let hovered { self.hovered=hovered }
        if let menuTracking { self.menuTracking=menuTracking }
        // Apply even interactions shorter than the 250ms presentation refresh.
        _=visibility.update(now:ProcessInfo.processInfo.systemUptime,autoHide:autoHideEnabled,
                            hovered:self.hovered,menuTracking:self.menuTracking)
    }
    func resetVisibility() { visibility.reset() }
    func hide() { panel.orderOut(nil);hovered=false;menuTracking=false;visibility.reset() }
}
