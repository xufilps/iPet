// SPDX-License-Identifier: Apache-2.0
import Foundation
/// Original schedule composition is based on base integer minutes, not execution progress.
public struct PetScheduleSummary:Equatable,Sendable {
    public let workMinutes,restMinutes:Double
    public let unresolvedEntryIDs:[Int]
    public let cycleSeconds:Double?
    public var workFraction:Double? {
        guard unresolvedEntryIDs.isEmpty,workMinutes+restMinutes>0 else { return nil }
        return workMinutes/(workMinutes+restMinutes)
    }
    public var isWorkHeavy:Bool { (workFraction ?? 0)>0.71 }
    public init(queue:PetScheduleQueue,catalog:PetCatalog) throws {
        try queue.validate();try catalog.validate()
        var work=0.0,rest=0.0,cycle=0.0,unresolved:[Int]=[]
        for entry in queue.entries {
            if let minutes=entry.waitMinutes {
                rest+=Double(minutes);cycle+=Double(minutes)*60
                continue
            }
            guard let id=entry.activityID,let base=catalog.activity(id),let effective=base.multiplied(by:entry.multiplier) else {
                unresolved.append(entry.id);continue
            }
            let minutes=(base.durationSeconds/60).rounded(.towardZero)
            if base.kind == .play {
                let half=(minutes/2).rounded(.towardZero)
                work+=half;rest+=half // C# integer Work.Time/2 in both buckets.
            } else { work+=minutes }
            cycle+=effective.durationSeconds+30
        }
        workMinutes=work;restMinutes=rest;unresolvedEntryIDs=unresolved
        cycleSeconds=queue.entries.isEmpty || !unresolved.isEmpty ? nil:cycle
    }
}
