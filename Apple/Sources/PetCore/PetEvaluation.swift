// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct PetEvaluationSummary:Equatable,Sendable {
    public let activeDays,streak,longestStreak,longestSessionSeconds:Double
    public let todaySeconds,monthSeconds,recent7Seconds,recent30Seconds:Double
}
/// Mirrors upstream local eval_* counters; not a rating or Steam statistic.
public struct PetEvaluation {
    private var calendar:Calendar
    private var sessionSeconds=0.0
    public init(timeZone:TimeZone = .autoupdatingCurrent) {
        calendar=Calendar(identifier:.gregorian);calendar.timeZone=timeZone
    }
    private func day(_ date:Date)->Int {
        let c=calendar.dateComponents([.year,.month,.day],from:date)
        return (c.year ?? 1970)*10000+(c.month ?? 1)*100+(c.day ?? 1)
    }
    private func shifted(_ date:Date,days:Int)->Date { calendar.date(byAdding:.day,value:days,to:date) ?? date }
    private func dayKey(_ date:Date)->String { "eval_day_"+String(format:"%08d",day(date)) }
    private func monthKey(_ date:Date)->String { "eval_month_"+String(format:"%06d",day(date)/100) }
    public mutating func begin(progress:inout PetProgress,now:Date) {
        sessionSeconds=0;register(progress:&progress,now:now)
    }
    private func register(progress:inout PetProgress,now:Date) {
        if progress.counters==nil { progress.counters=[:] }
        let today=Double(day(now))
        guard progress.counters!["eval_last_active_day",default:0] != today else { return }
        let yesterday=Double(day(shifted(now,days:-1)))
        let streak=progress.counters!["eval_last_active_day",default:0] == yesterday ? progress.counters!["eval_active_streak",default:0]+1:1
        progress.counters!["eval_last_active_day"]=today
        progress.increment("eval_active_days")
        progress.counters!["eval_active_streak"]=streak
        progress.counters!["eval_longest_active_streak"]=max(progress.counters!["eval_longest_active_streak",default:0],streak)
        let cutoff=day(shifted(now,days:-30))
        for key in Array(progress.counters!.keys) where key.hasPrefix("eval_day_") {
            if let value=Int(key.dropFirst("eval_day_".count)),value<cutoff { progress.counters!.removeValue(forKey:key) }
        }
    }
    public mutating func advance(progress:inout PetProgress,now:Date,seconds:Double) {
        guard seconds.isFinite,seconds>0 else { return }
        register(progress:&progress,now:now);sessionSeconds+=seconds
        progress.counters!["eval_longest_session_seconds"]=max(progress.counters!["eval_longest_session_seconds",default:0],sessionSeconds)
        progress.increment(dayKey(now),by:seconds);progress.increment(monthKey(now),by:seconds)
        progress.counters!["eval_recent_7_days_seconds"]=sum(progress:progress,now:now,days:7)
        progress.counters!["eval_recent_30_days_seconds"]=sum(progress:progress,now:now,days:30)
    }
    private func sum(progress:PetProgress,now:Date,days:Int)->Double {
        (0..<days).reduce(0) { $0+(progress.counters?[dayKey(shifted(now,days:-$1))] ?? 0) }
    }
    public func summary(progress:PetProgress,now:Date)->PetEvaluationSummary {
        let c=progress.counters ?? [:]
        return PetEvaluationSummary(activeDays:c["eval_active_days",default:0],streak:c["eval_active_streak",default:0],longestStreak:c["eval_longest_active_streak",default:0],longestSessionSeconds:c["eval_longest_session_seconds",default:0],todaySeconds:c[dayKey(now),default:0],monthSeconds:c[monthKey(now),default:0],recent7Seconds:sum(progress:progress,now:now,days:7),recent30Seconds:sum(progress:progress,now:now,days:30))
    }
    private static func type(_ kind:ActivityKind)->String { kind == .work ? "work":"study" }
    private static func updateRate(progress:inout PetProgress,type:String) {
        let started=progress.counters?["eval_"+type+"_started"] ?? 0
        progress.counters!["eval_"+type+"_completion_rate"]=started>0 ? (progress.counters?["eval_"+type+"_completed"] ?? 0)/started:0
    }
    public static func started(progress:inout PetProgress,work:ActivityDefinition) {
        let type=type(work.kind);progress.increment("eval_"+type+"_started")
        // .NET Uri.EscapeDataString uses RFC3986 unreserved bytes, including uppercase hex escapes.
        let escaped=work.name.utf8.map { byte -> String in
            if (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || [45,46,95,126].contains(byte) { return String(UnicodeScalar(byte)) }
            return String(format:"%%%02X",byte)
        }.joined()
        let key="eval_"+type+"_project_"+escaped
        if key.count<=400 { progress.increment(key) }
        else { progress.increment("eval_"+type+"_project_name_untracked") }
        updateRate(progress:&progress,type:type)
    }
    public static func ended(progress:inout PetProgress,kind:ActivityKind,reason:ActivityStopReason,earned:Double,bonus:Double) {
        let type=type(kind)
        if reason == .completed { progress.increment("eval_"+type+"_completed") }
        progress.increment(type == "work" ? "eval_work_total_money":"eval_study_total_exp",by:earned+(reason == .completed ? bonus:0))
        updateRate(progress:&progress,type:type)
    }
}
