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
                    let activity=model.catalog.activity(session.activityID)
                    let feedback=ActivityFeedback(session:session,activity:activity,mood:model.state.mood)
                    Text(feedback.title).font(.headline)
                    if let activity,let progress=feedback.progress {
                        ProgressView(value:progress)
                        Text("\(Int(session.elapsedSeconds/60)) / \(Int(activity.durationSeconds/60)) 分钟 · 已获 \(session.earned.formatted(.number.precision(.fractionLength(2)))) \(activity.kind == .work ? "金币" : "经验")")
                    }
                    HStack {
                        if session.isPaused { Button("继续活动") { model.perform(.resumeActivity) }.disabled(!feedback.canResume) }
                        else { Button("暂停活动") { model.perform(.pauseActivity) } }
                        Button("结束活动") { model.perform(.stopActivity) }
                    }
                    Text("提前结束保留已获收益；仅正常完成可获得完成奖励。切换活动会结束当前活动。").font(.caption).foregroundStyle(.secondary)
                    Divider()
                }
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
                ForEach(activities) { activity in
                    HStack {
                        Button { model.toggleFavoriteActivity(id:activity.id) } label: {
                            Image(systemName:model.favoriteActivities.contains(activity.id) ? "star.fill":"star")
                        }.accessibilityLabel(model.favoriteActivities.contains(activity.id) ? "取消收藏活动":"收藏活动")
                        VStack(alignment:.leading,spacing:4) {
                            Text("\(activity.kind.title) · \(activity.name)")
                            Text(activity.decisionDescription).font(.caption).foregroundStyle(.secondary)
                            Text("\(Int(activity.durationSeconds/60)) 分钟 · 完成奖励 \(Int(activity.finishBonus*100))% · 等级 \(activity.levelLimit)+").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(!model.simulationEnabled ? "养成已关闭":model.state.level < activity.levelLimit ? "等级不足" : model.state.mood == .ill ? "生病中" : "开始") { model.perform(.startActivity(activity.id)) }
                            .disabled(!model.simulationEnabled || model.state.level < activity.levelLimit || model.state.mood == .ill)
                    }.padding(10).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
                }
            }.padding(16)
        }
    }
}
