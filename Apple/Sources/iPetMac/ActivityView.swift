// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore
struct ActivityView: View {
    @ObservedObject var model: AppModel
    @State private var search=""
    @State private var kind:ActivityKind?
    @State private var favoritesOnly=false
    @State private var sort:PetActivitySort = .catalog
    @State private var ascending=true
    private var activities:[ActivityDefinition] {
        PetActivityQuery(search:search,kind:kind,favoritesOnly:favoritesOnly,sort:sort,ascending:ascending)
            .evaluate(catalog:model.catalog,favorites:model.favoriteActivities)
    }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                if let session=model.state.activity {
                    let base=model.catalog.activity(session.activityID)
                    let activity=model.catalog.activity(for:session)
                    let feedback=ActivityFeedback(session:session,activity:base,mood:model.state.mood)
                    Text("\(feedback.title) · \(session.effectiveMultiplier) 倍").font(.headline)
                    if let activity,let progress=feedback.progress {
                        ProgressView(value:progress)
                        Text("\(Int(session.elapsedSeconds/60)) / \(Int(activity.durationSeconds/60)) 分钟 · 已获 \(session.earned.formatted(.number.precision(.fractionLength(2)))) \(activity.kind == .work ? "金币" : "经验")")
                    }
                    HStack {
                        if session.isPaused { Button("继续活动") { model.perform(.resumeActivity) }.disabled(!feedback.canResume || (session.scheduleEntryID != nil && !model.scheduleAccess.allows(.resume,state:model.state))) }
                        else { Button("暂停活动") { model.perform(.pauseActivity) } }
                        Button("结束活动") { model.perform(.stopActivity) }
                    }
                    if session.scheduleEntryID != nil {
                        Button("查看日程与运行控制") { model.selectedPage = .schedule }
                        Text("此活动由日程执行。未达到整数分钟半程就结束会停止日程，达到后间隔30秒继续；暂停/继续活动会同步暂停/继续日程。").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("提前结束保留已获收益；仅正常完成可获得完成奖励。切换活动会结束当前活动。").font(.caption).foregroundStyle(.secondary)
                    Divider()
                }
                DisclosureGroup("任务套餐") { PackageView(model:model) }
                TextField("搜索活动名称",text:$search)
                HStack {
                    Picker("类别",selection:$kind) {
                        Text("全部").tag(Optional<ActivityKind>.none)
                        ForEach(ActivityKind.allCases,id:\.self) { Text($0.title).tag(Optional($0)) }
                    }
                    Toggle("只看收藏",isOn:$favoritesOnly)
                }
                HStack {
                    Picker("排序",selection:$sort) {
                        ForEach(PetActivitySort.allCases,id:\.self) { Text($0.title).tag($0) }
                    }
                    Toggle("升序",isOn:$ascending)
                }
                if !model.simulationEnabled { Text("养成已关闭，开启后可开始活动。").font(.caption).foregroundStyle(.secondary) }
                if activities.isEmpty { Text("没有符合条件的活动，可以调整搜索或筛选条件。").foregroundStyle(.secondary) }
                Text("倍率调整需求和等级门槛，收益按原版平衡公式重算，并非等比例增长；更改选择不影响已开始的会话。").font(.caption).foregroundStyle(.secondary)
                ForEach(activities) { activity in ActivityMultiplierRow(model:model,base:activity) }
            }.padding(16)
        }
    }
}

private struct ActivityMultiplierRow:View {
    @ObservedObject var model:AppModel
    let base:ActivityDefinition
    @State private var multiplier=1
    private var maximum:Int { base.maximumMultiplier(level:model.state.level) }
    private var selected:Int { min(maximum,max(1,multiplier)) }
    private var work:ActivityDefinition { base.multiplied(by:selected) ?? base }
    var body:some View {
        HStack {
            Button { model.toggleFavoriteActivity(id:base.id) } label: {
                Image(systemName:model.favoriteActivities.contains(base.id) ? "star.fill":"star")
            }.accessibilityLabel(model.favoriteActivities.contains(base.id) ? "取消收藏活动":"收藏活动")
            VStack(alignment:.leading,spacing:4) {
                Text("\(base.kind.title) · \(base.name)")
                if maximum>1 { Stepper("倍率 \(selected)",value:$multiplier,in:1...maximum) }
                Text(work.decisionDescription).font(.caption).foregroundStyle(.secondary)
                Text("\(Int(work.durationSeconds/60)) 分钟 · 完成奖励 \(Int(work.finishBonus*100))% · 等级 \(work.levelLimit)+").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(!model.simulationEnabled ? "养成已关闭":model.state.level < work.levelLimit ? "等级不足" : model.state.mood == .ill ? "生病中" : model.state.activity?.activityID == base.id ? "停止":"开始") {
                model.perform(.startMultipliedActivity(base.id,multiplier:selected))
            }.disabled(!model.simulationEnabled || model.state.level < work.levelLimit || model.state.mood == .ill)
        }.padding(10).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
            .onChange(of:maximum) { _,value in multiplier=min(value,max(1,multiplier)) }
    }
}
