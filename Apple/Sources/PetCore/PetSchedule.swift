// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetSchedulePhase:String,Codable,Sendable { case stopped,activity,waiting,handoff }
public enum PetScheduleCommand:Sendable { case edit(PetScheduleEdit),start,stop,pause,resume }
public struct PetSchedule:Codable,Equatable,Sendable {
    public var queue:PetScheduleQueue
    public var phase:PetSchedulePhase = .stopped
    public var isPaused=false
    public var nextIndex=0
    public var currentEntryID:Int?
    public var remainingSeconds=0.0
    public var message=""
    public var isRunning:Bool { phase != .stopped }
    public init(queue:PetScheduleQueue=PetScheduleQueue()) { self.queue=queue }
    public func validate(activity:ActivitySession?) throws {
        try queue.validate()
        guard (0...queue.entries.count).contains(nextIndex),message.count<=4096,
              remainingSeconds.isFinite,(0...86400).contains(remainingSeconds) else { throw PetSaveError.invalidState }
        if phase == .stopped {
            guard currentEntryID==nil,remainingSeconds==0,!isPaused,activity?.scheduleEntryID==nil else { throw PetSaveError.invalidState }
            return
        }
        guard let id=currentEntryID,let entry=queue.entries.first(where:{ $0.id==id }) else { throw PetSaveError.invalidState }
        switch phase {
        case .activity:
            guard remainingSeconds==0,entry.activityID != nil,activity?.scheduleEntryID==id,
                  activity?.activityID==entry.activityID,activity?.effectiveMultiplier==entry.multiplier,
                  activity?.isPaused==isPaused else { throw PetSaveError.invalidState }
        case .waiting:
            guard entry.waitMinutes != nil,remainingSeconds>0,remainingSeconds<=Double(entry.waitMinutes!)*60,activity==nil else { throw PetSaveError.invalidState }
        case .handoff:
            guard entry.activityID != nil,remainingSeconds>0,remainingSeconds<=30,activity==nil else { throw PetSaveError.invalidState }
        case .stopped:break
        }
    }
}
