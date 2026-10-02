// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore
struct StatisticsView:View {
    @ObservedObject var model:AppModel
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:12) {
                Text("统计从本版本实际操作开始；未导入或估算旧历史。仅记录已实现的经济与活动入口。").font(.caption).foregroundStyle(.secondary)
                if let progress=model.state.progress {
                    Text("购买 \(progress.purchased) 件 · 使用 \(progress.used) 件 · 实际支出 \(number(progress.spent)) 金币")
                    Text("活动金币收入 \(number(progress.moneyEarned)) · 活动经验收入 \(number(progress.experienceEarned))（含完成奖金）")
                    Text("工作 \(number(progress.workSeconds/60)) 分钟 · 学习 \(number(progress.studySeconds/60)) 分钟 · 娱乐 \(number(progress.playSeconds/60)) 分钟")
                    if let counters=progress.counters {
                        Divider()
                        Text("原版口径统计（新增项目从本次升级后开始）").font(.headline)
                        Text("养成计算 \(number(counters["stat_total_time",default:0]/60)) 分钟 · 强制休息 \(number(counters["stat_sleep_time",default:0]/60)) 分钟")
                        Text("摸头 \(number(counters["stat_touch_head",default:0])) 次 · 摸身体 \(number(counters["stat_touch_body",default:0])) 次；捏脸开始各计一次。")
                        Text("消费标价累计 \(number(counters["stat_betterbuy",default:0])) 金币（含库存使用，不代表实际支出）").font(.caption)
                        ForEach(ItemCategory.allCases,id:\.self) { category in
                            Text("\(category.title)：使用 \(number(counters["use_category_"+category.rawValue,default:0])) 件 · 标价 \(number(counters["stat_bb_"+category.rawValue,default:0])) 金币").font(.caption)
                        }
                        Text("药品原始经验累计 \(number(counters["stat_bb_drug_exp",default:0])) · 礼品原始好感累计 \(number(counters["stat_bb_gift_like",default:0]))（未乘食用衰减）").font(.caption)
                        Text("全满状态采样 \(number(counters["stat_100_all",default:0])) 次").font(.caption)
                        let flags=lowFlags.filter { counters[$0.0,default:0]>0 }.map(\.1)
                        if !flags.isEmpty { Text("记录过："+flags.joined(separator:"、")).font(.caption).foregroundStyle(.secondary) }
                    }
                    Divider()
                    Text("活动结束记录 · 累计 \(progress.activityEnds) 次，保留最近200条").font(.headline)
                    if progress.history.isEmpty { Text("尚无结束记录，正在进行的活动仍在活动页显示。").foregroundStyle(.secondary) }
                    ForEach(progress.history.reversed()) { record in
                        VStack(alignment:.leading,spacing:4) {
                            Text("\(record.name) · \(record.multiplier ?? 1) 倍 · \(reason(record.reason))").font(.headline)
                            Text(record.date.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                            Text("有效时间 \(number(record.seconds/60)) 分钟 · 收益 \(number(record.earned)) · 奖金 \(number(record.bonus)) \(record.kind == .work ? "金币":record.kind == nil ? "（类型未知）":"经验")").font(.caption).monospacedDigit()
                        }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
                    }
                } else { Text("尚无统计记录。购买、使用物品或进行活动后，会开始记录。").foregroundStyle(.secondary) }
            }.padding(16).frame(maxWidth:.infinity,alignment:.leading)
        }
    }
    private let lowFlags=[("stat_ill_nomoney","生病且金币不足100"),("stat_level_g_money","金币低于等级"),("stat_0_feel","心情低于1"),("stat_0_strengthfood","饱腹低于1"),("stat_0_strengthdrink","饮水低于1"),("stat_0_all","体力/心情/饱腹/饮水同时低于1")]
    private func number(_ value:Double)->String { value.formatted(.number.precision(.fractionLength(0...2))) }
    private func reason(_ value:ActivityStopReason)->String {
        switch value { case .completed:"完成";case .manual:"手动结束";case .stateFailed:"状态不足停止" }
    }
}
