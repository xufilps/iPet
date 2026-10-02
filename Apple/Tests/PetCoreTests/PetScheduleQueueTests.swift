// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetScheduleQueueTests:XCTestCase {
    private let now=Date(timeIntervalSince1970:1_000_000)
    private func activity(_ kind:ActivityKind = .work) -> ActivityDefinition {
        ActivityDefinition(id:kind.rawValue,name:"活动",graphID:"test",kind:kind,durationSeconds:660,levelLimit:5,moneyBase:8,strengthFood:3.5,strengthDrink:2.5,feeling:1,finishBonus:0.1)
    }
    private func state() -> PetState {
        var s=PetState();s.experience=36100
        s.workPackage=PetSignedPackage(definitionID:"work",name:"工作",description:"",kind:.work,commission:0.2,price:100,level:40,endTime:now.addingTimeInterval(3600))
        s.studyPackage=PetSignedPackage(definitionID:"study",name:"学习",description:"",kind:.study,commission:0.2,price:100,level:40,endTime:now.addingTimeInterval(3600))
        return s
    }
    private func edit(_ queue:inout PetScheduleQueue,_ command:PetScheduleEdit,state:PetState?=nil,locked:Bool=false) -> PetCommandResult {
        queue.edit(command,state:state ?? self.state(),catalog:PetCatalog(activities:ActivityKind.allCases.map { activity($0) }),now:now,locked:locked)
    }
    func testAppendMergesOnlyTrailingWaitAndPreservesIdentity() throws {
        var q=PetScheduleQueue()
        XCTAssertTrue(edit(&q,.appendWait(minutes:30)).accepted)
        XCTAssertTrue(edit(&q,.appendWait(minutes:30)).accepted)
        XCTAssertEqual(q.entries.count,1);XCTAssertEqual(q.entries[0].id,1);XCTAssertEqual(q.entries[0].waitMinutes,60)
        XCTAssertTrue(edit(&q,.appendActivity("work",multiplier:1)).accepted)
        XCTAssertTrue(edit(&q,.appendWait(minutes:30)).accepted)
        XCTAssertEqual(q.entries.map(\.id),[1,2,3]);XCTAssertEqual(q.nextID,4)
        XCTAssertTrue(edit(&q,.insertWait(before:2,minutes:30)).accepted)
        XCTAssertEqual(q.entries.map(\.id),[1,4,2,3]);XCTAssertEqual(q.entries.map(\.waitMinutes),[60,30,nil,30])
    }
    func testRemovingBetweenWaitsMergesIntoPreviousWait() throws {
        var q=PetScheduleQueue()
        _=edit(&q,.appendWait(minutes:30));_=edit(&q,.appendActivity("work",multiplier:1));_=edit(&q,.appendWait(minutes:60))
        XCTAssertTrue(edit(&q,.remove(2)).accepted)
        XCTAssertEqual(q.entries.map(\.id),[1]);XCTAssertEqual(q.entries[0].waitMinutes,90)
        _=edit(&q,.appendActivity("study",multiplier:1));XCTAssertEqual(q.entries.map(\.id),[1,4])
    }
    func testMovingBetweenWaitsUsesOriginalMergeBeforeInsertion() throws {
        for offset in [-1,1] {
            var q=PetScheduleQueue()
            _=edit(&q,.appendWait(minutes:30));_=edit(&q,.appendActivity("work",multiplier:1));_=edit(&q,.appendWait(minutes:60))
            XCTAssertTrue(edit(&q,.move(2,offset:offset)).accepted)
            XCTAssertEqual(q.entries.map(\.id),offset == -1 ? [2,1]:[1,2])
            XCTAssertEqual(q.entries.first { $0.id==1 }?.waitMinutes,90)
        }
    }
    func testEditingFailuresAreAtomicAndLockedQueueCannotChange() throws {
        var q=PetScheduleQueue();_=edit(&q,.appendWait(minutes:1440));let before=q
        for command:PetScheduleEdit in [.appendWait(minutes:1),.appendWait(minutes:0),.appendWait(minutes:Int.max),.remove(999),.move(1,offset:2),.insertWait(before:999,minutes:30),.appendActivity("work",multiplier:0),.appendActivity("work",multiplier:401),.appendActivity("unknown",multiplier:1)] {
            XCTAssertFalse(edit(&q,command).accepted);XCTAssertEqual(q,before)
        }
        XCTAssertFalse(edit(&q,.remove(1),locked:true).accepted);XCTAssertEqual(q,before)
        XCTAssertTrue(edit(&q,.move(1,offset:-1)).accepted);XCTAssertEqual(q,before)
    }
    func testAddRequiresEffectivePackageLevelAndActiveContractWithoutRenewal() throws {
        var q=PetScheduleQueue(),s=state();s.experience=84100 // Level30; work x2 effective requirement30.
        s.workPackage?.level=29
        XCTAssertFalse(edit(&q,.appendActivity("work",multiplier:2),state:s).accepted)
        s.workPackage?.level=30
        XCTAssertTrue(edit(&q,.appendActivity("work",multiplier:2),state:s).accepted)
        s.workPackage?.endTime=now;s.workPackage?.autoRenew=true
        let before=s
        XCTAssertFalse(edit(&q,.appendActivity("work",multiplier:1),state:s).accepted)
        XCTAssertEqual(s,before);XCTAssertEqual(q.entries.count,1)
        s.studyPackage=nil;XCTAssertFalse(edit(&q,.appendActivity("study",multiplier:1),state:s).accepted)
    }
    func testPlayRequiresFifteenAndSelectorRejectsExcessMultiplier() throws {
        var q=PetScheduleQueue(),s=state();s.experience=16900 // Level14.
        XCTAssertFalse(edit(&q,.appendActivity("play",multiplier:1),state:s).accepted)
        s.experience=19600
        XCTAssertTrue(edit(&q,.appendActivity("play",multiplier:1),state:s).accepted)
        XCTAssertFalse(edit(&q,.appendActivity("work",multiplier:2),state:s).accepted)
    }
    func testCapacityFailureAndWaitMergeAtCapacity() throws {
        var q=PetScheduleQueue()
        for _ in 0..<999 { XCTAssertTrue(edit(&q,.appendActivity("work",multiplier:1)).accepted) }
        XCTAssertTrue(edit(&q,.appendWait(minutes:30)).accepted)
        let before=q
        XCTAssertFalse(edit(&q,.appendActivity("work",multiplier:1)).accepted);XCTAssertEqual(q,before)
        XCTAssertTrue(edit(&q,.appendWait(minutes:30)).accepted);XCTAssertEqual(q.entries.last?.waitMinutes,60)
    }
    func testUnknownActivityRoundTripAndCorruptShapeRejected() throws {
        let json=Data(#"{"entries":[{"id":1,"activityID":"missing.mod.activity","multiplier":2}],"nextID":2}"#.utf8)
        let q=try JSONDecoder().decode(PetScheduleQueue.self,from:json)
        XCTAssertEqual(q.entries[0].activityID,"missing.mod.activity")
        XCTAssertEqual(try JSONDecoder().decode(PetScheduleQueue.self,from:JSONEncoder().encode(q)),q)
        for raw in [
            #"{"entries":[{"id":1,"activityID":"work","waitMinutes":30,"multiplier":1}],"nextID":2}"#,
            #"{"entries":[{"id":1,"waitMinutes":30,"multiplier":2}],"nextID":2}"#,
            #"{"entries":[{"id":1,"waitMinutes":30,"multiplier":1},{"id":1,"waitMinutes":30,"multiplier":1}],"nextID":2}"#,
            #"{"entries":[{"id":1,"waitMinutes":30,"multiplier":1}],"nextID":1}"#,
            #"{"entries":[],"nextID":9223372036854775807}"#
        ] { XCTAssertThrowsError(try JSONDecoder().decode(PetScheduleQueue.self,from:Data(raw.utf8))) }
    }
    func testEditingWaitChangesDurationWithoutIdentityOrInvalidPartialChanges() throws {
        var q=PetScheduleQueue();_=edit(&q,.appendWait(minutes:30));_=edit(&q,.appendActivity("work",multiplier:1))
        XCTAssertTrue(edit(&q,.setWait(1,minutes:5)).accepted)
        XCTAssertEqual(q.entries[0].waitMinutes,5);XCTAssertEqual(q.entries.map(\.id),[1,2]);XCTAssertEqual(q.nextID,3)
        let before=q
        for command:PetScheduleEdit in [.setWait(1,minutes:0),.setWait(1,minutes:1441),.setWait(2,minutes:30),.setWait(999,minutes:30)] {
            XCTAssertFalse(edit(&q,command).accepted);XCTAssertEqual(q,before)
        }
        XCTAssertFalse(edit(&q,.setWait(1,minutes:10),locked:true).accepted);XCTAssertEqual(q,before)
    }
    func testMergeOverflowDuringRemovalPreservesEveryEntry() throws {
        var q=PetScheduleQueue()
        _=edit(&q,.appendWait(minutes:1440));_=edit(&q,.appendActivity("work",multiplier:1));_=edit(&q,.appendWait(minutes:30));let before=q
        XCTAssertFalse(edit(&q,.remove(2)).accepted);XCTAssertEqual(q,before)
        XCTAssertFalse(edit(&q,.move(2,offset:1)).accepted);XCTAssertEqual(q,before)
    }
}
