// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore
struct ScheduleView:View {
    @ObservedObject var model:AppModel
    @State private var activityID=""
    @State private var multiplier=1
    private var schedule:PetSchedule { model.state.schedule ?? PetSchedule() }
    private var activity:ActivityDefinition? { model.catalog.activity(activityID) ?? model.catalog.activities.first }
    private var maximum:Int { activity?.maximumMultiplier(level:model.state.level) ?? 1 }
    private var selectedMultiplier:Int { min(maximum,max(1,multiplier)) }
    private var effective:ActivityDefinition? { activity?.multiplied(by:selectedMultiplier) }
    private var editable:Bool { model.scheduleAccess.allows(.edit(.appendWait(minutes:30)),state:model.state) }
    private var status:String {
        if !schedule.isRunning { return "已停止" }
        let phase = switch schedule.phase {
        case .activity:"活动中"
        case .waiting:"等待中"
        case .handoff:"活动间衔接"
        case .stopped:"已停止"
        }
        return schedule.isPaused ? "已暂停 · \(phase)":phase
    }
    var body:some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:14) {
                Text("日程 · \(status)").font(.headline)
                if let summary=try? PetScheduleSummary(queue:schedule.queue,catalog:model.catalog) {
                    ScheduleCompositionView(summary:summary)
                } else { Text("日程汇总数据不可用，请检查玩法目录与队列。").font(.caption).foregroundStyle(.orange) }
                if let current=schedule.queue.entries.first(where:{ $0.id==schedule.currentEntryID }) {
                    Text("当前：\(title(current))")
                    if schedule.phase == .waiting || schedule.phase == .handoff {
                        Text("剩余 \(Int(ceil(schedule.remainingSeconds))) 秒").monospacedDigit()
                    }
                    if let next=nextEntry { Text("下一项：\(title(next))").font(.caption).foregroundStyle(.secondary) }
                }
                if !schedule.message.isEmpty { Text(schedule.message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
                HStack {
                    Button("开始循环") { model.perform(.schedule(.start)) }.disabled(!model.scheduleAccess.allows(.start,state:model.state))
                    Button(schedule.isPaused ? "继续日程":"暂停日程") { model.perform(.schedule(schedule.isPaused ? .resume:.pause)) }
                        .disabled(!model.scheduleAccess.allows(schedule.isPaused ? .resume:.pause,state:model.state))
                    Button("停止日程") { model.perform(.schedule(.stop)) }.disabled(!model.scheduleAccess.allows(.stop,state:model.state))
                }
                Text("启动从第一项循环；启动及每项开始前会检查一次已开启的到期续费，可能扣款。等待不强制睡觉，活动结束后间隔30秒。未达到整数分钟半程就结束活动会停止日程；半程后结束则继续。停止日程保留当前活动和暂停状态，手动休息或切换活动退出日程。").font(.caption).foregroundStyle(.secondary)
                if let session=model.state.activity,session.scheduleEntryID != nil {
                    Button("查看当前活动与收益") { model.selectedPage = .activity }
                }
                if model.packageWriteFailed {
                    Text("保存失败，日程已暂停，后续扣款和队列修改已锁定。重试只保存当前状态，成功后请手动继续。").font(.caption).foregroundStyle(.orange)
                    Button("重试保存当前状态") { model.save() }.disabled(!model.scheduleAccess.canRetrySave)
                }
                if !model.simulationEnabled { Text("养成已关闭，可编辑队列，开启后再运行。").font(.caption).foregroundStyle(.secondary) }
                Divider()
                Text("日程队列（\(schedule.queue.entries.count)项）").font(.headline)
                if schedule.queue.entries.isEmpty { Text("添加活动或等待，组成循环日程。").foregroundStyle(.secondary) }
                ForEach(Array(schedule.queue.entries.enumerated()),id:\.element.id) { index,entry in
                    VStack(alignment:.leading,spacing:6) {
                        Text("\(index+1). \(title(entry))\(entry.id==schedule.currentEntryID ? " · 当前":"")")
                        if let minutes=entry.waitMinutes {
                            Stepper("等待\(minutes)分钟",value:Binding(get:{ minutes },set:{ model.perform(.schedule(.edit(.setWait(entry.id,minutes:$0)))) }),in:1...1440).disabled(!editable)
                        }
                        if let id=entry.activityID,model.catalog.activity(id)==nil {
                            Text("活动定义不可用，启动到此项会停止；请先停止日程，再删除或替换。").font(.caption).foregroundStyle(.orange)
                        }
                        HStack {
                            Button("上移") { model.perform(.schedule(.edit(.move(entry.id,offset:-1)))) }.disabled(!editable || index==0)
                            Button("下移") { model.perform(.schedule(.edit(.move(entry.id,offset:1)))) }.disabled(!editable || index==schedule.queue.entries.count-1)
                            Button("前插等待30分钟") { model.perform(.schedule(.edit(.insertWait(before:entry.id,minutes:30)))) }.disabled(!editable)
                            Button("删除") { model.perform(.schedule(.edit(.remove(entry.id)))) }.disabled(!editable)
                        }.controlSize(.small)
                    }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
                }
                Text("编辑时尾部等待会累加；删除或移动夹在两段等待之间的项目会先合并两段等待。运行与暂停期间均不能修改，需先停止日程。").font(.caption).foregroundStyle(.secondary)
                if let activity {
                    Picker("添加活动",selection:Binding(get:{ self.activity?.id ?? "" },set:{ activityID=$0;multiplier=1 })) {
                        ForEach(model.catalog.activities) { Text("\($0.kind.title) · \($0.name)").tag($0.id) }
                    }.disabled(!editable)
                    if maximum>1 { Stepper("倍率 \(selectedMultiplier)",value:$multiplier,in:1...maximum).disabled(!editable) }
                    if let effective {
                        Text("\(Int(effective.durationSeconds/60))分钟 · 选择需要宠物等级\(effective.levelLimit)+\(activity.kind == .play ? "；娱乐日程还需15级":"，添加需同类有效套餐授权\(effective.levelLimit)+")。执行按基础授权\(activity.levelLimit)+检查，宠物等级不足时降低倍率。").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("加入日程") { model.perform(.schedule(.edit(.appendActivity(activity.id,multiplier:selectedMultiplier)))) }
                        .disabled(!editable)
                }
                Button("追加等待30分钟") { model.perform(.schedule(.edit(.appendWait(minutes:30)))) }.disabled(!editable)
                Text("最多1000项，每段等待不超过1440分钟；超出时整次编辑拒绝，已有队列保留。加载或恢复存档后日程保持暂停，不补算退出和睡眠期间时间。").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("工作与学习套餐") { PackageView(model:model) }
            }.padding(16)
        }.onChange(of:maximum) { _,value in multiplier=min(value,max(1,multiplier)) }
    }
    private var nextEntry:PetScheduleEntry? {
        guard schedule.isRunning,!schedule.queue.entries.isEmpty else { return nil }
        return schedule.queue.entries[schedule.nextIndex % schedule.queue.entries.count]
    }
    private func title(_ entry:PetScheduleEntry) -> String {
        if let minutes=entry.waitMinutes { return "等待\(minutes)分钟" }
        let id=entry.activityID ?? "未知活动"
        return "\(model.catalog.activity(id)?.name ?? id) · \(entry.multiplier)倍"
    }
}

private struct ScheduleCompositionView:View {
    let summary:PetScheduleSummary
    private var tint:Color { summary.isWorkHeavy ? .orange:.accentColor }
    private var ratio:String { summary.workFraction?.formatted(.percent.precision(.fractionLength(0))) ?? "—" }
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(spacing:16) {
                ZStack {
                    Circle().stroke(.quaternary,lineWidth:8)
                    Circle().trim(from:0,to:summary.workFraction ?? 0).stroke(tint,style:StrokeStyle(lineWidth:8,lineCap:.butt)).rotationEffect(.degrees(-90))
                    VStack(spacing:3) {
                        Text(ratio).font(.title3.bold()).foregroundStyle(tint).monospacedDigit()
                        Text("工作比例").font(.caption)
                    }
                }.frame(width:100,height:100)
                    .accessibilityElement(children:.ignore).accessibilityLabel("配置工作比例：\(ratio)")
                VStack(alignment:.leading,spacing:6) {
                    Text("\(summary.unresolvedEntryIDs.isEmpty ? "配置合计":"已识别部分合计")").font(.headline)
                    Text("工作/学习 \(summary.workMinutes.formatted(.number.precision(.fractionLength(0)))) 分钟")
                    Text("休息 \(summary.restMinutes.formatted(.number.precision(.fractionLength(0)))) 分钟")
                    if summary.isWorkHeavy { Text("工作比例超过71%，可增加等待或娱乐。").font(.caption).foregroundStyle(.orange) }
                }
            }
            if !summary.unresolvedEntryIDs.isEmpty {
                Text("\(summary.unresolvedEntryIDs.count)项无法完整解析，比例和整轮估计暂不提供；项目仍保留在队列。").font(.caption).foregroundStyle(.orange)
            }
            Text("沿原版配置比例：娱乐的整数分钟均分为工作和休息，奇数分钟截断；不计倍率后的时长与30秒衔接。此图不表示当前执行进度。").font(.caption).foregroundStyle(.secondary)
            if let seconds=summary.cycleSeconds {
                Text("自然完成时一轮参考：\((seconds/60).formatted(.number.precision(.fractionLength(0...1))))分钟（含有效倍率时长与30秒衔接）。暂停、提前结束、状态中止或降倍率会改变实际时间。").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
    }
}
