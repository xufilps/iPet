// SPDX-License-Identifier: Apache-2.0
/// Shared native control gates. PetEngine remains responsible for data/rule validation.
public struct PetScheduleAccess:Sendable {
    public let writable,saveFailed,busy,simulationEnabled:Bool
    public init(writable:Bool,saveFailed:Bool,busy:Bool,simulationEnabled:Bool) {
        self.writable=writable;self.saveFailed=saveFailed;self.busy=busy;self.simulationEnabled=simulationEnabled
    }
    public var canRetrySave:Bool { writable && !busy }
    public func allows(_ command:PetScheduleCommand,state:PetState) -> Bool {
        guard !busy else { return false }
        let running=state.schedule?.isRunning == true,paused=state.schedule?.isPaused == true
        switch command {
        case .stop:return running
        case .pause:return running && !paused
        case .edit:return writable && !saveFailed && !running
        case .start:return writable && !saveFailed && simulationEnabled && !running && !(state.schedule?.queue.entries.isEmpty ?? true)
        case .resume:return writable && !saveFailed && simulationEnabled && running && paused
        }
    }
}
