// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct PetActivityRecord:Codable,Equatable,Sendable,Identifiable {
    public let id:Int
    public let date:Date
    public let activityID,name:String
    public let kind:ActivityKind?
    public let reason:ActivityStopReason
    public let seconds,earned,bonus:Double
}
public struct PetProgress:Codable,Equatable,Sendable {
    public var purchased=0,used=0,activityEnds=0
    public var spent=0.0,moneyEarned=0.0,experienceEarned=0.0
    public var workSeconds=0.0,studySeconds=0.0,playSeconds=0.0
    public var history:[PetActivityRecord]=[]
    public init() {}
    public func validate() throws {
        guard [purchased,used,activityEnds].allSatisfy({ (0...1_000_000_000_000).contains($0) }),
              [spent,moneyEarned,experienceEarned,workSeconds,studySeconds,playSeconds].allSatisfy({ $0.isFinite && (0...1e12).contains($0) }),
              history.count<=200,Set(history.map(\.id)).count==history.count else { throw PetSaveError.invalidState }
        for record in history {
            guard record.id>0,record.id<=activityEnds,!record.activityID.isEmpty,record.activityID.count<=300,!record.name.isEmpty,record.name.count<=300,
                  record.date.timeIntervalSince1970.isFinite,abs(record.date.timeIntervalSince1970)<=1e12,
                  [record.seconds,record.earned,record.bonus].allSatisfy({ $0.isFinite && (0...1e12).contains($0) }) else { throw PetSaveError.invalidState }
        }
    }
    mutating func recordTime(kind:ActivityKind,seconds:Double) {
        switch kind { case .work:workSeconds+=seconds;case .study:studySeconds+=seconds;case .play:playSeconds+=seconds }
    }
    mutating func recordGain(kind:ActivityKind,amount:Double) {
        if kind == .work { moneyEarned+=amount } else { experienceEarned+=amount }
    }
    mutating func recordEnd(session:ActivitySession,work:ActivityDefinition?,reason:ActivityStopReason,bonus:Double,date:Date) {
        activityEnds+=1
        history.append(PetActivityRecord(id:activityEnds,date:date,activityID:session.activityID,name:work?.name ?? session.activityID,kind:work?.kind,reason:reason,seconds:session.elapsedSeconds,earned:session.earned,bonus:bonus))
        if history.count>200 { history.removeFirst(history.count-200) }
        if let work { recordGain(kind:work.kind,amount:bonus) }
    }
}
