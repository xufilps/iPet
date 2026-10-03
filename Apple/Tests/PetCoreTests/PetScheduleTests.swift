// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetScheduleTests:XCTestCase {
    private func saved() -> PetState {
        var s=PetState();s.experience=84100;s.money=10000
        s.workPackage=PetSignedPackage(definitionID:"basic",name:"套餐",description:"",kind:.work,commission:0.2,price:2900,level:12,endTime:Date(timeIntervalSince1970:2_000_000))
        return s
    }
    private func engine(_ s:PetState?=nil,seconds:Double=660) -> (PetEngine,FakeClock) {
        let clock=FakeClock(),wall=FixedWallClock();wall.now=Date(timeIntervalSince1970:1_000_000)
        return (PetEngine(state:s ?? saved(),clock:clock,random:FixedRandom(),catalog:PetCatalog(activities:[testWork(seconds:seconds)],packages:[PetPackageDefinition(id:"basic",name:"套餐",kind:.work,commission:0.2,unitPrice:1,levelRatio:1.25,durationDays:7)]),wallClock:wall),clock)
    }
    private func advance(_ engine:PetEngine,_ clock:FakeClock,_ seconds:Double) {
        var left=seconds
        while left>0 { let delta=min(left,15);clock.now+=delta;engine.tick();left-=delta }
    }
    func testWaitLoopsWithoutForcingSleepOrOfflineCatchup() throws {
        let (e,c)=engine()
        XCTAssertTrue(e.perform(.schedule(.edit(.appendWait(minutes:1)))).accepted)
        XCTAssertTrue(e.perform(.schedule(.start)).accepted)
        XCTAssertEqual(e.state.schedule?.phase,.waiting);XCTAssertFalse(e.state.resting)
        advance(e,c,45);XCTAssertEqual(e.state.schedule?.remainingSeconds,15)
        c.now+=3600;e.tick();XCTAssertEqual(e.state.schedule?.remainingSeconds,15)
        advance(e,c,15);XCTAssertEqual(e.state.schedule?.remainingSeconds,60);XCTAssertEqual(e.state.schedule?.currentEntryID,1)
    }
    func testCompletedWorkGetsFullThirtySecondHandoffThenWait() throws {
        let (e,c)=engine(seconds:15)
        _=e.perform(.schedule(.edit(.appendActivity("work",multiplier:1))));_=e.perform(.schedule(.edit(.appendWait(minutes:1))));_=e.perform(.schedule(.start))
        advance(e,c,15);XCTAssertNotNil(e.state.activity)
        advance(e,c,1);XCTAssertNil(e.state.activity);XCTAssertEqual(e.state.schedule?.phase,.handoff);XCTAssertEqual(e.state.schedule?.remainingSeconds,30)
        advance(e,c,29);XCTAssertEqual(e.state.schedule?.remainingSeconds,1)
        advance(e,c,1);XCTAssertEqual(e.state.schedule?.phase,.waiting);XCTAssertEqual(e.state.schedule?.remainingSeconds,60)
        advance(e,c,60);XCTAssertEqual(e.state.activity?.activityID,"work");XCTAssertEqual(e.state.activity?.elapsedSeconds,0)
    }
    func testIntegerMinuteHalfBoundaryStopsEarlyButContinuesLate() throws {
        for elapsed in [299.0,300.0] { // Work.Time11 /2 is integer5 minutes.
            let (e,c)=engine()
            _=e.perform(.schedule(.edit(.appendActivity("work",multiplier:1))));_=e.perform(.schedule(.start));advance(e,c,elapsed)
            _=e.perform(.stopActivity)
            XCTAssertEqual(e.state.schedule?.phase,elapsed<300 ? .stopped:.handoff)
            XCTAssertEqual(e.state.schedule?.remainingSeconds,elapsed<300 ? 0:30)
        }
    }
    func testStopKeepsActivityAndManualReplacementExitsSchedule() throws {
        let (e,c)=engine()
        _=e.perform(.schedule(.edit(.appendActivity("work",multiplier:1))));_=e.perform(.schedule(.start));advance(e,c,10)
        _=e.perform(.schedule(.stop));XCTAssertEqual(e.state.activity?.elapsedSeconds,10);XCTAssertNil(e.state.activity?.scheduleEntryID)
        _=e.perform(.stopActivity);advance(e,c,30);XCTAssertNil(e.state.activity);XCTAssertEqual(e.state.schedule?.phase,.stopped)
        _=e.perform(.schedule(.start));_=e.perform(.startActivity("work"));XCTAssertEqual(e.state.schedule?.phase,.stopped)
        _=e.perform(.schedule(.start));_=e.send(.toggleRest);XCTAssertEqual(e.state.schedule?.phase,.stopped);XCTAssertTrue(e.state.resting)
    }
    func testPauseFreezesOwnedActivityAndQueueEditing() throws {
        let (e,c)=engine()
        _=e.perform(.schedule(.edit(.appendActivity("work",multiplier:1))));_=e.perform(.schedule(.start));advance(e,c,20)
        _=e.perform(.pauseActivity);advance(e,c,30)
        XCTAssertTrue(e.state.schedule!.isPaused);XCTAssertEqual(e.state.activity?.elapsedSeconds,20)
        let before=e.state
        XCTAssertFalse(e.perform(.schedule(.edit(.remove(1)))).accepted);XCTAssertEqual(e.state,before)
        XCTAssertTrue(e.perform(.resumeActivity).accepted);advance(e,c,10);XCTAssertEqual(e.state.activity?.elapsedSeconds,30)
        _=e.perform(.schedule(.stop));_=e.perform(.schedule(.edit(.remove(1))));_=e.perform(.stopActivity)
        _=e.perform(.schedule(.edit(.appendWait(minutes:1))));_=e.perform(.schedule(.start));_=e.perform(.schedule(.pause));advance(e,c,30)
        XCTAssertEqual(e.state.schedule?.remainingSeconds,60)
        _=e.perform(.schedule(.resume));advance(e,c,15);XCTAssertEqual(e.state.schedule?.remainingSeconds,45)
    }
    func testExecutionRequiresBaseContractAndDowngradesPetMultiplier() throws {
        var s=saved();s.workPackage?.level=1 // base0 allowed, effective x2 requires20 at add time.
        var q=PetScheduleQueue();var high=saved();high.workPackage?.level=40
        XCTAssertTrue(q.edit(.appendActivity("work",multiplier:2),state:high,catalog:PetCatalog(activities:[testWork()]),now:Date(timeIntervalSince1970:1_000_000)).accepted)
        s.growth = .initial;s.experience=0;s.schedule=PetSchedule(queue:q)
        let (e,_)=engine(s)
        XCTAssertTrue(e.perform(.schedule(.start)).accepted)
        XCTAssertEqual(e.state.activity?.effectiveMultiplier,1);XCTAssertEqual(e.state.schedule?.queue.entries[0].multiplier,1)
        s.workPackage=nil;let (missing,_)=engine(s)
        let response=missing.perform(.schedule(.start));XCTAssertTrue(response.accepted);XCTAssertNil(missing.state.activity);XCTAssertEqual(missing.state.schedule?.phase,.stopped)
    }
    func testRenewBeforeWaitAndFailedDispatchRetainsPaidState() throws {
        var s=saved();s.workPackage?.endTime=Date(timeIntervalSince1970:999999);s.workPackage?.autoRenew=true
        let (e,_)=engine(s)
        _=e.perform(.schedule(.edit(.appendWait(minutes:1))));_=e.perform(.schedule(.start))
        XCTAssertEqual(e.state.money,7700);XCTAssertEqual(e.state.workPackage?.level,9);XCTAssertEqual(e.state.workPackage?.autoRenew,false)
        let q=try JSONDecoder().decode(PetScheduleQueue.self,from:Data(#"{"entries":[{"id":1,"activityID":"missing","multiplier":1}],"nextID":2}"#.utf8))
        s.schedule=PetSchedule(queue:q);let (bad,_)=engine(s)
        XCTAssertTrue(bad.perform(.schedule(.start)).accepted);XCTAssertEqual(bad.state.money,7700);XCTAssertEqual(bad.state.schedule?.phase,.stopped)
        XCTAssertTrue(bad.state.schedule!.message.contains("不可用"));XCTAssertEqual(bad.state.schedule?.queue.entries[0].activityID,"missing")
    }
    func testRenewalStillOccursWhenWaitingTimerExpires() throws {
        let c=FakeClock(),wall=FixedWallClock();wall.now=Date(timeIntervalSince1970:1_000_000)
        var s=saved();s.workPackage?.endTime=wall.now.addingTimeInterval(10);s.workPackage?.autoRenew=true
        let catalog=PetCatalog(packages:[PetPackageDefinition(id:"basic",name:"套餐",kind:.work,commission:0.2,unitPrice:1,levelRatio:1.25,durationDays:7)])
        let e=PetEngine(state:s,clock:c,catalog:catalog,wallClock:wall)
        _=e.perform(.schedule(.edit(.appendWait(minutes:1))));_=e.perform(.schedule(.start))
        XCTAssertEqual(e.state.money,10000)
        wall.now+=60;advance(e,c,60)
        XCTAssertEqual(e.state.money,7700);XCTAssertEqual(e.state.workPackage?.autoRenew,false)
        try e.state.validate()
    }
    func testMalformedRuntimeCannotBeSaved() throws {
        let (e,_)=engine();_=e.perform(.schedule(.edit(.appendWait(minutes:1))));_=e.perform(.schedule(.start))
        for invalid in [0.0,-1.0,61.0,Double.nan] {
            var s=e.state;s.schedule?.remainingSeconds=invalid;XCTAssertThrowsError(try s.validate())
        }
        var s=e.state;s.schedule?.nextIndex=100;XCTAssertThrowsError(try s.validate())
        s=e.state;s.schedule?.phase = .activity;XCTAssertThrowsError(try s.validate())
    }
    func testLoadedScheduleAndActivityPauseAndVersionSixBackup() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
        let store=PetSaveStore(directory:dir), (e,c)=engine()
        _=e.perform(.schedule(.edit(.appendActivity("work",multiplier:1))));_=e.perform(.schedule(.start));advance(e,c,20)
        try store.save(e.state)
        let loaded=try XCTUnwrap(store.load());XCTAssertTrue(loaded.schedule!.isPaused);XCTAssertTrue(loaded.activity!.isPaused);XCTAssertEqual(loaded.activity?.elapsedSeconds,20)
        XCTAssertTrue(try store.previewImport(store.exportSnapshot(e.state)).schedule!.isPaused)
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:store.exportSnapshot(saved())) as? [String:Any]);object["version"]=6
        let legacy=try JSONSerialization.data(withJSONObject:historicalSaveObject(object));try legacy.write(to:store.primary)
        let old=try XCTUnwrap(store.load());XCTAssertNil(old.schedule);try store.save(old)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),legacy)
        XCTAssertEqual(PetSaveDocument(state:old).version,9)
        let future=Data(#"{"version":10}"#.utf8);try future.write(to:store.primary)
        XCTAssertThrowsError(try store.save(old));XCTAssertEqual(try Data(contentsOf:store.primary),future)
    }
    func testInvalidOwnershipRejectedAndDisabledSimulationStopsSchedule() throws {
        let (e,_)=engine()
        _=e.perform(.schedule(.edit(.appendActivity("work",multiplier:1))));_=e.perform(.schedule(.start))
        var corrupt=e.state;corrupt.activity?.scheduleEntryID=999;XCTAssertThrowsError(try corrupt.validate())
        e.configureSimulation(enabled:false,fixedMood:.normal);XCTAssertEqual(e.state.schedule?.phase,.stopped);XCTAssertNil(e.state.activity)
        XCTAssertFalse(e.perform(.schedule(.start)).accepted)
    }
}
