import XCTest
@testable import PetCore

final class PetAutonomyTests: XCTestCase {
    func testOriginalSelectionBoundariesAndIdleCount() {
        let expected: [(Double, PetAutonomousBehavior?)] = [(0,.walkLeft),(2.0/200,.walkLeft),(3.0/200,.fidget),(5.0/200,.fidget),(6.0/200,.specialIdle),(7.0/200,.doze),(8.0/200,nil),(11.0/200,nil)]
        for (value, result) in expected {
            let clock=FakeClock(), scheduler=PetAutonomy(clock:clock,random:FixedRandom(value:value))
            clock.now=14.99;XCTAssertNil(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal))
            clock.now=15;XCTAssertEqual(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal),result)
        }
        let clock=FakeClock(), scheduler=PetAutonomy(clock:clock,random:FixedRandom(value:0.15))
        for _ in 0..<185 { scheduler.recordIdleCycle() }
        clock.now=15;XCTAssertEqual(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal),.fidget)
        XCTAssertEqual(scheduler.idleCycles,0)
    }
    func testMovementSwitchAndIllnessDoNotSubstituteSleep() {
        for (enabled,mood) in [(false,PetMood.normal),(true,.ill)] {
            let clock=FakeClock(), scheduler=PetAutonomy(clock:clock,random:FixedRandom())
            clock.now=15;XCTAssertNil(scheduler.poll(eligible:true,allowsMovement:enabled,mood:mood))
        }
        let clock=FakeClock(), scheduler=PetAutonomy(clock:clock,random:FixedRandom(value:7.0/200))
        clock.now=15;XCTAssertEqual(scheduler.poll(eligible:true,allowsMovement:false,mood:.ill),.doze)
    }
    func testBusyHiddenAndLongGapNeverCatchUp() {
        let clock=FakeClock(), scheduler=PetAutonomy(clock:clock,random:FixedRandom(value:7.0/200))
        clock.now=15;XCTAssertNil(scheduler.poll(eligible:false,allowsMovement:true,mood:.normal))
        clock.now=16;XCTAssertNil(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal))
        clock.now=1000;XCTAssertNil(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal))
        clock.now=1015;XCTAssertEqual(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal),.doze)
        scheduler.reset();clock.now=1029;XCTAssertNil(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal))
        clock.now=900;XCTAssertNil(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal))
    }
    func testEligibilityProtectsActivitiesAndTransientActions() {
        var state=PetState()
        XCTAssertTrue(PetAutonomy.canStart(state:state,action:.idle,visible:true,interacting:false,finishing:false))
        for action in [PetAction.eat,.drink,.gift,.head,.body,.raised,.sleep,.fidget,.activity] {
            XCTAssertFalse(PetAutonomy.canStart(state:state,action:action,visible:true,interacting:false,finishing:false))
        }
        for flags in [(false,false,false),(true,true,false),(true,false,true)] {
            XCTAssertFalse(PetAutonomy.canStart(state:state,action:.idle,visible:flags.0,interacting:flags.1,finishing:flags.2))
        }
        state.resting=true
        XCTAssertFalse(PetAutonomy.canStart(state:state,action:.idle,visible:true,interacting:false,finishing:false))
        state.resting=false;state.activity=ActivitySession(activityID:"workone")
        XCTAssertFalse(PetAutonomy.canStart(state:state,action:.idle,visible:true,interacting:false,finishing:false))
        state.activity?.isPaused=true
        XCTAssertFalse(PetAutonomy.canStart(state:state,action:.idle,visible:true,interacting:false,finishing:false))
    }
    func testSeededRunsAgreeAndChooseBothDirections() {
        func run() -> [PetAutonomousBehavior?] {
            let clock=FakeClock(), scheduler=PetAutonomy(clock:clock,random:SeededPetRandom(seed:37))
            return (1...500).map { n in
                for _ in 0..<200 { scheduler.recordIdleCycle() }
                clock.now=Double(n)*15
                return scheduler.poll(eligible:true,allowsMovement:true,mood:.normal)
            }
        }
        let results=run();XCTAssertEqual(results,run())
        XCTAssertTrue(results.contains(.walkLeft));XCTAssertTrue(results.contains(.walkRight))
    }
    func testConfiguredCycleChangesSelectionAndPreservesSchedule() {
        let clock=FakeClock()
        let scheduler=PetAutonomy(clock:clock,random:FixedRandom(value:0.1),interactionCycle:200)
        clock.now=15;XCTAssertNil(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal))
        scheduler.setInteractionCycle(30)
        clock.now=16;XCTAssertNil(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal))
        clock.now=30;XCTAssertEqual(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal),.fidget)
        XCTAssertEqual(scheduler.interactionCycle,30)
    }
    func testCycleClampingAndIdleRandomFloor() {
        let clock=FakeClock(),scheduler=PetAutonomy(clock:clock,random:FixedRandom(value:0.15),interactionCycle:Int.max)
        XCTAssertEqual(scheduler.interactionCycle,1000)
        for _ in 0..<990 { scheduler.recordIdleCycle() }
        scheduler.setInteractionCycle(1000)
        XCTAssertEqual(scheduler.idleCycles,990)
        clock.now=15;XCTAssertEqual(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal),.fidget)
        scheduler.setInteractionCycle(Int.min);XCTAssertEqual(scheduler.interactionCycle,30)
    }

    func testActiveActivityEligibilityAndOriginalDoubleRange() {
        var state=PetState();state.activity=ActivitySession(activityID:"work")
        XCTAssertTrue(PetAutonomy.canStart(state:state,action:.activity,visible:true,interacting:false,finishing:false))
        XCTAssertFalse(PetAutonomy.canStart(state:state,action:.idle,visible:true,interacting:false,finishing:false))
        XCTAssertFalse(PetAutonomy.canStart(state:state,action:.activity,visible:true,interacting:false,finishing:true))
        state.activity?.isPaused=true
        XCTAssertFalse(PetAutonomy.canStart(state:state,action:.activity,visible:true,interacting:false,finishing:false))
        for (working,expected) in [(false,Optional<PetAutonomousBehavior>(.walkLeft)),(true,Optional(.fidget))] {
            let clock=FakeClock(),scheduler=PetAutonomy(clock:clock,random:FixedRandom(value:3.0/420))
            clock.now=15;XCTAssertEqual(scheduler.poll(eligible:true,allowsMovement:true,mood:.normal,working:working),expected)
        }
    }

}
