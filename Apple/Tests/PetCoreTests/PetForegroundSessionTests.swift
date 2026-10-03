// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore

private final class ForegroundClock: PetClock { var now = 0.0 }
final class PetForegroundSessionTests: XCTestCase {
    func testRepeatedActivationPreservesForegroundTime() {
        let clock=ForegroundClock(), engine=PetEngine(clock:ForegroundClock())
        let session=PetForegroundSession(engine:engine,clock:clock)
        session.activate()
        for _ in 0..<3 { clock.now += 15; XCTAssertFalse(session.tick()) }
        session.activate();clock.now += 15
        XCTAssertTrue(session.tick());XCTAssertTrue(session.isActive)
        XCTAssertFalse(session.tick())
    }
    func testBackgroundIsNeverAdvancedAndForegroundTailIsRetained() {
        let clock=ForegroundClock()
        let engine=PetEngine(clock:clock,random:SeededPetRandom(seed:1))
        let session=PetForegroundSession(engine:engine,clock:clock)
        session.activate();clock.now=15;_ = session.tick()
        clock.now=20;session.deactivate()
        let before=engine.state
        clock.now=140;XCTAssertFalse(session.tick());XCTAssertEqual(engine.state,before)
        session.activate();clock.now=155;_ = session.tick()
        let referenceClock=ForegroundClock()
        let reference=PetEngine(clock:referenceClock,random:SeededPetRandom(seed:1))
        referenceClock.now=15;reference.tick();referenceClock.now=20;reference.tick()
        reference.resetClock();referenceClock.now=35;reference.tick()
        // resetClock discards fractional rule time at suspension, matching the existing engine contract.
        XCTAssertEqual(engine.state.strength,reference.state.strength)
        XCTAssertEqual(engine.state.food,reference.state.food)
        XCTAssertEqual(engine.state.money,reference.state.money)
    }
    func testAutosaveUsesActiveSecondsOnly() {
        let clock=ForegroundClock(), engine=PetEngine()
        let session=PetForegroundSession(engine:engine,clock:clock)
        session.activate();clock.now=20;XCTAssertFalse(session.tick());session.deactivate()
        clock.now=200;session.activate()
        clock.now=220;XCTAssertFalse(session.tick())
        clock.now=240;XCTAssertTrue(session.tick())
    }
    func testClockJumpDoesNotRequestCatchupSave() {
        let clock=ForegroundClock(), engine=PetEngine()
        let session=PetForegroundSession(engine:engine,clock:clock)
        session.activate();clock.now=120;XCTAssertFalse(session.tick())
        clock.now=110;XCTAssertFalse(session.tick())
        clock.now=125;XCTAssertFalse(session.tick())
    }
    func testActivationDoesNotResumeUserPausedActivity() {
        let clock=ForegroundClock()
        let catalog=PetCatalog(activities:[ActivityDefinition(id:"work",name:"工作",graphID:"workone",kind:.work,durationSeconds:120,moneyBase:1,strengthFood:1,strengthDrink:1,feeling:1,finishBonus:1)])
        let engine=PetEngine(clock:clock,catalog:catalog)
        XCTAssertTrue(engine.perform(.startActivity("work")).accepted)
        XCTAssertTrue(engine.perform(.pauseActivity).accepted)
        let session=PetForegroundSession(engine:engine,clock:clock)
        session.activate();clock.now=15;_ = session.tick();session.deactivate()
        clock.now=300;session.activate();clock.now=315;_ = session.tick()
        XCTAssertEqual(engine.state.activity?.isPaused,true)
        XCTAssertEqual(engine.state.activity?.elapsedSeconds,0)
    }
}
