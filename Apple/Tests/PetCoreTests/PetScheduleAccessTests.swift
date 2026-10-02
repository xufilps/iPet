// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetScheduleAccessTests:XCTestCase {
    private func state(running:Bool=false,paused:Bool=false) -> PetState {
        var state=PetState(),queue=PetScheduleQueue()
        _=queue.edit(.appendWait(minutes:1),state:state,catalog:PetCatalog(),now:Date())
        var schedule=PetSchedule(queue:queue)
        if running { schedule.phase = .waiting;schedule.currentEntryID=1;schedule.nextIndex=1;schedule.remainingSeconds=60;schedule.isPaused=paused }
        state.schedule=schedule;return state
    }
    private func access(writable:Bool=true,failed:Bool=false,busy:Bool=false,simulation:Bool=true) -> PetScheduleAccess {
        PetScheduleAccess(writable:writable,saveFailed:failed,busy:busy,simulationEnabled:simulation)
    }
    func testReadOnlyAndFailedSaveBlockFinancialActionsButAllowStop() {
        for gate in [access(writable:false),access(failed:true)] {
            XCTAssertFalse(gate.allows(.start,state:state()))
            XCTAssertFalse(gate.allows(.resume,state:state(running:true,paused:true)))
            XCTAssertFalse(gate.allows(.edit(.appendWait(minutes:30)),state:state()))
            XCTAssertTrue(gate.allows(.stop,state:state(running:true)))
            XCTAssertTrue(gate.allows(.pause,state:state(running:true)))
        }
        XCTAssertFalse(access(writable:false).canRetrySave);XCTAssertTrue(access(failed:true).canRetrySave)
    }
    func testBusyUseBlocksAllScheduleOperationsAndSaveRetry() {
        let gate=access(busy:true)
        for command:PetScheduleCommand in [.start,.resume,.pause,.stop,.edit(.appendWait(minutes:30))] {
            XCTAssertFalse(gate.allows(command,state:state(running:true,paused:true)))
        }
        XCTAssertFalse(gate.canRetrySave)
    }
    func testDisabledSimulationPermitsEditingButNotExecution() {
        let gate=access(simulation:false)
        XCTAssertTrue(gate.allows(.edit(.appendWait(minutes:30)),state:state()))
        XCTAssertFalse(gate.allows(.start,state:state()))
        XCTAssertFalse(gate.allows(.resume,state:state(running:true,paused:true)))
        XCTAssertTrue(gate.allows(.stop,state:state(running:true)))
    }
    func testRunningAndPausedQueuesCannotEditOrRestart() {
        for paused in [true,false] {
            let state=state(running:true,paused:paused),gate=access()
            XCTAssertFalse(gate.allows(.edit(.remove(1)),state:state))
            XCTAssertFalse(gate.allows(.start,state:state))
            XCTAssertEqual(gate.allows(.resume,state:state),paused)
            XCTAssertEqual(gate.allows(.pause,state:state),!paused)
        }
        XCTAssertTrue(access().allows(.start,state:state()))
        XCTAssertFalse(access().allows(.start,state:PetState()))
    }
    func testSaveRecoveryRequiresExplicitResumeAndDoesNotChangeState() {
        let paused=state(running:true,paused:true)
        XCTAssertFalse(access(failed:true).allows(.resume,state:paused))
        XCTAssertTrue(access().allows(.resume,state:paused))
        XCTAssertTrue(paused.schedule!.isPaused);XCTAssertEqual(paused.schedule?.remainingSeconds,60)
    }
}
