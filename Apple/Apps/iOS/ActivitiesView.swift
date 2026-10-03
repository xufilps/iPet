// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore

struct IOSActivitiesView: View {
    @EnvironmentObject private var model:IOSPetModel
    var body:some View {
        List {
            if let feedback=model.activityFeedback { Section { IOSActivityStatus(feedback:feedback) } }
            Section { Text(model.message).foregroundStyle(.secondary) }
            ForEach(ActivityKind.allCases,id:\.self) { kind in
                Section(kind.title) {
                    ForEach(model.catalog.activities.filter { $0.kind == kind }) { activity in
                        VStack(alignment:.leading,spacing:8) {
                            HStack {
                                Text(activity.name).font(.headline);Spacer()
                                Text("Lv.\(activity.levelLimit)").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(activity.decisionDescription).font(.caption).foregroundStyle(.secondary)
                            Button(model.state.activity?.activityID == activity.id ? "停止当前活动":"开始\(activity.name)") {
                                model.perform(model.state.activity?.activityID == activity.id ? .stopActivity:.startActivity(activity.id))
                            }.buttonStyle(.glass)
                                .disabled(!model.canOperate || model.state.activity?.activityID != activity.id && (model.state.level<activity.levelLimit || model.state.mood == .ill))
                        }.padding(.vertical,6)
                    }
                }
            }
        }.navigationTitle("活动")
    }
}
