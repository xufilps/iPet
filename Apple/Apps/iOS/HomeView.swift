// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore

struct IOSHomeView: View {
    @EnvironmentObject private var model: IOSPetModel
    var body: some View {
        ScrollView {
            VStack(spacing:20) {
                HStack {
                    VStack(alignment:.leading) {
                        Text(model.state.name).font(.largeTitle.bold())
                        Text("Lv.\(model.state.level) · \(model.state.mood.title)").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(model.state.money.formatted(.number.precision(.fractionLength(2))),systemImage:"creditcard").monospacedDigit()
                }
                if let scene=model.scene {
                    PetStageView(scene:scene,active:model.active && model.saveError.isEmpty,onTouch:model.touch)
                        .aspectRatio(1,contentMode:.fit).frame(maxWidth:360)
                        .accessibilityLabel("\(model.state.name)，轻点摸头")
                        .accessibilityAction { model.interact(.touchHead) }
                }
                IOSPetActions().disabled(!model.canOperate)
                if !model.speechText.isEmpty {
                    IOSMessageBubble()
                }
                VStack(alignment:.leading,spacing:12) {
                    status("体力",model.state.strength,model.state.strengthMax,.orange)
                    status("饱腹",model.state.food,model.state.strengthMax,.green)
                    status("饮水",model.state.drink,model.state.strengthMax,.blue)
                    status("心情",model.state.feeling,model.state.feelingMax,.pink)
                    status("健康",model.state.health,100,.red)
                }.padding().background(.background,in:.rect(cornerRadius:24))
                if let feedback=model.activityFeedback { IOSActivityStatus(feedback:feedback) }
                Text(model.message).font(.callout).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
                if !model.saveError.isEmpty {
                    Text(model.saveError).foregroundStyle(.red)
                    Button("重试保存",action:model.save).buttonStyle(.glassProminent)
                }
            }.padding().frame(maxWidth:620)
        }
        .background(Color(uiColor:.systemGroupedBackground))
        .navigationTitle("iPet").navigationBarTitleDisplayMode(.inline)
        .onAppear { model.setStageVisible(true) }
        .onDisappear { model.setStageVisible(false) }
    }
    private func status(_ title:String,_ value:Double,_ maximum:Double,_ color:Color) -> some View {
        VStack(spacing:4) {
            HStack { Text(title);Spacer();Text("\(value.formatted(.number.precision(.fractionLength(1)))) / \(maximum.formatted(.number.precision(.fractionLength(0))))").monospacedDigit().foregroundStyle(.secondary) }
            ProgressView(value:max(0,min(value,maximum)),total:max(1,maximum)).tint(color)
        }
    }
}

struct IOSMessageBubble:View {
    @EnvironmentObject private var model:IOSPetModel
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack { Text(model.state.name).font(.caption.bold());Spacer();Button("关闭",systemImage:"xmark",action:model.closeSpeech).labelStyle(.iconOnly) }
            Text(model.speechText).font(model.font).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
        }.padding().background(.background,in:.rect(cornerRadius:20)).opacity(model.speechOpacity)
    }
}

private struct IOSPetActions: View {
    @EnvironmentObject private var model: IOSPetModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var glass
    @State private var expanded=false
    var body: some View {
        let layout=dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing:20)):AnyLayout(HStackLayout(spacing:20))
        GlassEffectContainer(spacing:12) {
            VStack(spacing:12) {
                layout {
                    Button("投喂",systemImage:"fork.knife") { model.interact(.feed) }
                    Button("饮水",systemImage:"drop") { model.interact(.water) }
                    Button(expanded ? "收起":"更多",systemImage:expanded ? "chevron.up":"ellipsis") {
                        withAnimation(reduceMotion ? nil:.spring(response:0.35)) { expanded.toggle() }
                    }
                }.padding().buttonStyle(.plain)
                    .glassEffect(.regular.interactive(),in:.capsule).glassEffectID("primary",in:glass)
                if expanded {
                    layout {
                        Button(model.state.resting ? "起床":"休息",systemImage:model.state.resting ? "sun.max":"moon") { model.interact(.toggleRest) }
                        Button("摸头",systemImage:"hand.tap") { model.interact(.touchHead) }
                        Button("聊天",systemImage:"bubble.left") { model.chat() }
                    }.padding().buttonStyle(.plain)
                        .glassEffect(.regular.interactive(),in:.capsule).glassEffectID("secondary",in:glass)
                }
            }
        }
    }
}

struct IOSActivityStatus: View {
    @EnvironmentObject private var model: IOSPetModel
    let feedback:ActivityFeedback
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(feedback.title + (feedback.isPaused ? " · 已暂停":" · 进行中")).font(.headline)
            if let progress=feedback.progress { ProgressView(value:progress) }
            HStack {
                Text("收益 \(feedback.earned.formatted(.number.precision(.fractionLength(2)))) \(feedback.unit)")
                Spacer()
                if let remaining=feedback.remainingSeconds { Text("剩余 \(Int(ceil(remaining))) 秒").monospacedDigit() }
            }.font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(feedback.isPaused ? "继续":"暂停") { model.perform(feedback.isPaused ? .resumeActivity:.pauseActivity) }
                    .disabled(feedback.isPaused && !feedback.canResume)
                Button("停止",role:.destructive) { model.perform(.stopActivity) }
            }.buttonStyle(.glass).disabled(!model.canOperate)
        }.padding().background(.background,in:.rect(cornerRadius:20))
    }
}
