// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct PetActivityRecord:Codable,Equatable,Sendable,Identifiable {
    public let id:Int
    public let date:Date
    public let activityID,name:String
    public let kind:ActivityKind?
    public let reason:ActivityStopReason
    public let seconds,earned,bonus:Double
    public var multiplier:Int?=nil
}
public struct PetProgress:Codable,Equatable,Sendable {
    public var purchased=0,used=0,activityEnds=0
    public var spent=0.0,moneyEarned=0.0,experienceEarned=0.0
    public var workSeconds=0.0,studySeconds=0.0,playSeconds=0.0
    public var history:[PetActivityRecord]=[]
    public var counters:[String:Double]?
    public init() {}
    public func validate() throws {
        if let counters {
            guard counters.count<=10000,counters.allSatisfy({ !$0.key.isEmpty && $0.key.count<=400 && $0.value.isFinite && abs($0.value)<=1e12 }) else { throw PetSaveError.invalidState }
        }
        guard [purchased,used,activityEnds].allSatisfy({ (0...1_000_000_000_000).contains($0) }),
              [spent,moneyEarned,experienceEarned,workSeconds,studySeconds,playSeconds].allSatisfy({ $0.isFinite && (0...1e12).contains($0) }),
              history.count<=200,Set(history.map(\.id)).count==history.count else { throw PetSaveError.invalidState }
        for record in history {
            guard (1...400).contains(record.multiplier ?? 1),record.id>0,record.id<=activityEnds,!record.activityID.isEmpty,record.activityID.count<=300,!record.name.isEmpty,record.name.count<=300,
                  record.date.timeIntervalSince1970.isFinite,abs(record.date.timeIntervalSince1970)<=1e12,
                  [record.seconds,record.earned,record.bonus].allSatisfy({ $0.isFinite && (0...1e12).contains($0) }) else { throw PetSaveError.invalidState }
        }
    }
    mutating func increment(_ key:String,by value:Double=1) {
        if counters == nil { counters=[:] };counters![key,default:0]+=value
    }
    mutating func recordUse(_ item:ItemDefinition) {
        increment("stat_buytimes");increment("buy_"+item.id)
        increment("stat_betterbuy",by:item.price);increment("stat_bb_"+item.category.rawValue,by:item.price)
        increment("use_category_"+item.category.rawValue)
        if item.category == .drug { increment("stat_bb_drug_exp",by:item.experience) }
        if item.category == .gift { increment("stat_bb_gift_like",by:item.affection) }
    }
    mutating func recordSample(state:PetState,catalog:PetCatalog,mood:PetMood?=nil) {
        if counters == nil { counters=[:] }
        counters!["stat_money"]=state.money;counters!["stat_level"]=Double(state.level);counters!["stat_likability"]=state.affection
        increment("stat_total_time",by:15)
        if state.resting { increment("stat_sleep_time",by:15) }
        if let session=state.activity,!session.isPaused,let work=catalog.activity(session.activityID) {
            increment(work.kind == .work ? "stat_work_time":"stat_study_time",by:15)
        }
        func flag(_ key:String,_ condition:Bool) { if condition { counters![key]=1 } }
        flag("stat_ill_nomoney",(mood ?? state.mood) == .ill && state.money<100)
        flag("stat_level_g_money",state.money<Double(state.level))
        flag("stat_0_feel",state.feeling<1);flag("stat_0_f_sd",state.feeling<1 && state.drink<1)
        flag("stat_0_all",state.strength<1 && state.feeling<1 && state.food<1 && state.drink<1)
        flag("stat_0_strengthfood",state.food<1);flag("stat_0_strengthdrink",state.drink<1)
        flag("stat_0_sd_sf",state.food<1 && state.drink<1)
        if state.strength>99 && state.feeling>99 && state.food>99 && state.drink>99 { increment("stat_100_all") }
    }
    mutating func recordTime(kind:ActivityKind,seconds:Double) {
        switch kind { case .work:workSeconds+=seconds;case .study:studySeconds+=seconds;case .play:playSeconds+=seconds }
    }
    mutating func recordGain(kind:ActivityKind,amount:Double) {
        if kind == .work { moneyEarned+=amount } else { experienceEarned+=amount }
    }
    mutating func recordEnd(session:ActivitySession,work:ActivityDefinition?,reason:ActivityStopReason,bonus:Double,date:Date) {
        activityEnds+=1
        history.append(PetActivityRecord(id:activityEnds,date:date,activityID:session.activityID,name:work?.name ?? session.activityID,kind:work?.kind,reason:reason,seconds:session.elapsedSeconds,earned:session.earned,bonus:bonus,multiplier:session.multiplier))
        if history.count>200 { history.removeFirst(history.count-200) }
        if let work { recordGain(kind:work.kind,amount:bonus) }
    }
}
