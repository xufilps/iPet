// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore
struct ActivityView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                if let session=model.state.activity {
                    let activity=model.catalog.activity(session.activityID)
                    Text(activity?.name ?? "未识别的活动：\(session.activityID)").font(.headline)
                    if let activity {
                        ProgressView(value:min(session.elapsedSeconds,activity.durationSeconds),total:activity.durationSeconds)
                        Text("\(Int(session.elapsedSeconds/60)) / \(Int(activity.durationSeconds/60)) 分钟 · 已获 \(session.earned.formatted(.number.precision(.fractionLength(2)))) \(activity.kind == .work ? "金币" : "经验")")
                    }
                    HStack {
                        if session.isPaused { Button("继续活动") { model.perform(.resumeActivity) }.disabled(activity == nil || model.state.mood == .ill) }
                        else { Button("暂停活动") { model.perform(.pauseActivity) } }
                        Button("结束活动") { model.perform(.stopActivity) }
                    }
                    Text("提前结束保留已获收益；仅正常完成可获得完成奖励。切换活动会结束当前活动。").font(.caption).foregroundStyle(.secondary)
                    Divider()
                }
                ForEach(ActivityKind.allCases,id:\.self) { kind in
                    Text(kind.title).font(.headline)
                    ForEach(model.catalog.activities.filter { $0.kind == kind }) { activity in
                        HStack {
                            VStack(alignment:.leading,spacing:4) {
                                Text(activity.name)
                                Text("\(Int(activity.durationSeconds/60)) 分钟 · 完成奖励 \(Int(activity.finishBonus*100))% · 等级 \(activity.levelLimit)+").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.state.level < activity.levelLimit ? "等级不足" : model.state.mood == .ill ? "生病中" : "开始") { model.perform(.startActivity(activity.id)) }
                                .disabled(model.state.level < activity.levelLimit || model.state.mood == .ill)
                        }.padding(10).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
                    }
                }
            }.padding(16)
        }
    }
}
