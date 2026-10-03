// Source: VPet 1a06c598 Statistics and audited writer call sites; LinePutScript 1.11.9.
// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Numeric interpretation is source-key based, never inferred from an untagged stored value.
/// This is a subset preview, not a complete statistics or whole-save import candidate.
public struct PetLegacyStatisticsPreview:Sendable {
    public enum Kind:Sendable { case int32,int64,double }
    public enum Value:Equatable,Sendable { case int32(Int32),int64(Int64),double(Double)
        fileprivate var boundedCounter:Double? {
            switch self {
            case .int32(let value):return Double(value)
            case .int64(let value):return (-1_000_000_000_000...1_000_000_000_000).contains(value) ? Double(value):nil
            case .double(let value):return abs(value)<=1e12 ? value:nil
            }
        }
    }
    public struct Record:Sendable {
        public let sourceField:PetLegacyLPSDocument.Field
        public let expectedKind:Kind?
        public let value:Value?
    }
    public let sourceLines:[PetLegacyLPSDocument.Line]
    public let records:[Record]
    /// Representation-compatible subset only. Keys remain original; no counters are applied to PetState.
    /// buy_{name} needs inventory-ID mapping and is deliberately excluded.
    public let numericCounters:[String:Double]
    public let issues:[PetLegacySavePreview.Issue]
    public let omittedIssueCount:Int

    public init(document:PetLegacyLPSDocument) {
        let lines=document.lines.filter { $0.name.utf8.elementsEqual("statistics".utf8) }
        var mapper=Mapper();mapper.run(lines)
        sourceLines=lines;records=mapper.records;numericCounters=mapper.counters;issues=mapper.issues;omittedIssueCount=mapper.omitted
    }
    private static let int32Keys:Set<String> = ["stat_level","stat_ill_nomoney","stat_level_g_money","stat_0_feel","stat_0_f_sd","stat_0_all","stat_0_strengthfood","stat_0_strengthdrink","stat_0_sd_sf","stat_100_all","stat_buytimes","stat_say_exp_p","stat_say_exp_d","stat_say_like_p","stat_say_like_d","stat_say_money_p","stat_say_money_d","stat_menu_pop","stat_open_times","stat_single_profit_money","stat_single_profit_exp","stat_touch_body","stat_touch_head","stat_say_times","stat_move_length","eval_last_active_day","eval_active_days","eval_active_streak","eval_longest_active_streak","eval_work_started","eval_work_completed","eval_study_started","eval_study_completed"]
    private static let int64Keys:Set<String> = ["stat_total_time","stat_work_time","stat_study_time","stat_sleep_time","eval_longest_session_seconds","eval_recent_7_days_seconds","eval_recent_30_days_seconds"]
    private static let doubleKeys:Set<String> = ["stat_money","stat_likability","stat_betterbuy","stat_bb_food","stat_bb_drink","stat_bb_drug","stat_bb_snack","stat_bb_functional","stat_bb_meal","stat_bb_gift","stat_bb_drug_exp","stat_bb_gift_like","eval_work_total_money","eval_study_total_exp","eval_work_completion_rate","eval_study_completion_rate"]
    private static func kind(_ key:String) -> Kind? {
        if int32Keys.contains(key) { return .int32 }
        if int64Keys.contains(key) { return .int64 }
        if doubleKeys.contains(key) { return .double }
        if key.utf8.starts(with:"buy_".utf8),key.utf8.count>4 { return .int32 }
        for prefix in ["eval_work_project_","eval_study_project_"] where key.utf8.starts(with:prefix.utf8) {
            let suffix=String(key.dropFirst(prefix.count))
            // Uri.EscapeDataString emits ASCII unreserved characters and percent triplets.
            if !suffix.isEmpty,suffix.range(of:"^(?:[A-Za-z0-9._~-]|%[0-9A-F]{2})+$",options:.regularExpression) != nil { return .int32 }
        }
        if key.range(of:"^eval_day_[0-9]{8}$",options:.regularExpression) != nil || key.range(of:"^eval_month_[0-9]{6}$",options:.regularExpression) != nil { return .int64 }
        return nil
    }
    private struct Mapper {
        var records=[Record](),counters=[String:Double](),issues=[PetLegacySavePreview.Issue](),omitted=0
        mutating func report(_ key:String,_ text:String,_ severity:PetLegacySavePreview.Issue.Severity = .blocking) {
            if issues.count<200 { issues.append(.init(path:"statistics"+(key.isEmpty ? "":"."+key),message:text,severity:severity)) } else { omitted+=1 }
        }
        mutating func run(_ lines:[PetLegacyLPSDocument.Line]) {
            guard !lines.isEmpty else { report("","原统计根行缺失，原版使用空统计；没有估算历史。",.warning);return }
            let unique=lines.count==1
            if !unique { report("","多个统计根行，未选择一份冒充无歧义统计。") }
            for line in lines {
                if !line.rawInfo.isEmpty || !line.rawText.isEmpty { report("","统计行头/正文尚未解释，源数据保留。") }
                var occurrences=[Data:Int]()
                for field in line.fields { occurrences[Data(field.name.utf8),default:0]+=1 }
                for field in line.fields {
                    let expected=PetLegacyStatisticsPreview.kind(field.name)
                    var value:Value?
                    if occurrences[Data(field.name.utf8),default:0]>1 { report(field.name,"原统计字典拒绝重复键；保留每条记录，不挑选或累加。") }
                    else if let expected { value=parse(field,kind:expected) }
                    else { report(field.name,"没有核对过的内置类型用途，未猜测日期/布尔/固定点/文本；原info完整保留。") }
                    records.append(Record(sourceField:field,expectedKind:expected,value:value))
                    guard unique,let value else { continue }
                    if field.name.utf8.starts(with:"buy_".utf8) { report(field.name,"原购买计数按物品名称，本机按ID；须先完成库存ID映射，未擅自改名。");continue }
                    guard field.name.count<=400,let number=value.boundedCounter else { report(field.name,"超出原生计数器的名称/数值边界，精确类型化原值保留，不转换丢精度。");continue }
                    counters[field.name]=number
                }
            }
        }
        mutating func parse(_ field:PetLegacyLPSDocument.Field,kind:Kind) -> Value? {
            let raw=field.rawInfo
            switch kind {
            case .int32:if let value=Int32(raw),String(value)==raw { return .int32(value) }
            case .int64:if let value=Int64(raw),String(value)==raw { return .int64(value) }
            case .double:
                let pattern="^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"
                if raw.range(of:pattern,options:.regularExpression) != nil,let value=Double(raw),value.isFinite {
                    // A nonzero significand must not silently underflow into a zero counter.
                    let significand=raw.prefix { $0 != "e" && $0 != "E" }
                    if value != 0 || !significand.contains(where: { "123456789".contains($0) }) { return .double(value) }
                }
            }
            report(field.name,"不支持的规范统计数值，不按原宽松读取归零/截断/溢出或地区格式猜测。")
            return nil
        }
    }
}
