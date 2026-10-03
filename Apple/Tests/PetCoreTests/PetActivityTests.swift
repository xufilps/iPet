import XCTest
@testable import PetCore
func testWork(kind: ActivityKind = .work, seconds: Double = 3600, level: Int = 0) -> ActivityDefinition {
    ActivityDefinition(id: "work", name: "文案", graphID: "workone", kind: kind, durationSeconds: seconds, levelLimit: level, moneyBase: 8, strengthFood: 3.5, strengthDrink: 2.5, feeling: kind == .play ? -1 : 1, finishBonus: 0.1)
}
final class PetActivityTests: XCTestCase {
    func testWorkTickMatchesOriginal() {
        let clock=FakeClock(); let engine=PetEngine(clock: clock, random: FixedRandom(), catalog: PetCatalog(activities:[testWork()]))
        XCTAssertTrue(engine.perform(.startActivity("work")).accepted)
        clock.now=15; engine.tick()
        XCTAssertEqual(engine.state.strength,99.91,accuracy:1e-8)
        XCTAssertEqual(engine.state.food,99.8775,accuracy:1e-8)
        XCTAssertEqual(engine.state.drink,99.9125,accuracy:1e-8)
        XCTAssertEqual(engine.state.money,100.68,accuracy:1e-8)
        XCTAssertEqual(engine.state.experience,0.05,accuracy:1e-8)
    }
    func testStrictFinishAndManualStop() {
        let clock=FakeClock();let engine=PetEngine(clock:clock,random:FixedRandom(),catalog:PetCatalog(activities:[testWork(seconds:15)]))
        _=engine.perform(.startActivity("work"));clock.now=15;engine.tick();XCTAssertNotNil(engine.state.activity)
        clock.now=16;engine.tick();XCTAssertNil(engine.state.activity)
        XCTAssertEqual(engine.state.money,100.748,accuracy:1e-8)
        let events=engine.drainEvents();XCTAssertEqual(events.count,1);XCTAssertTrue(engine.drainEvents().isEmpty)
        clock.now=17;engine.tick();XCTAssertEqual(engine.state.money,100.748,accuracy:1e-8)
        _=engine.perform(.startActivity("work"));_=engine.perform(.stopActivity)
        XCTAssertEqual(engine.state.money,100.748,accuracy:1e-8)
    }
    func testStudyPlayAndGates() {
        for kind in [ActivityKind.study,.play] {
            let clock=FakeClock();let engine=PetEngine(clock:clock,random:FixedRandom(),catalog:PetCatalog(activities:[testWork(kind:kind)]))
            _=engine.perform(.startActivity("work"));clock.now=15;engine.tick()
            XCTAssertEqual(engine.state.money,100);XCTAssertEqual(engine.state.experience,0.73,accuracy:1e-8)
            if kind == .play { XCTAssertEqual(engine.state.feeling,60.05,accuracy:1e-8) }
        }
        var state=PetState();state.health=10
        let ill=PetEngine(state:state,catalog:PetCatalog(activities:[testWork()]));XCTAssertFalse(ill.perform(.startActivity("work")).accepted)
        let locked=PetEngine(catalog:PetCatalog(activities:[testWork(level:5)]));XCTAssertFalse(locked.perform(.startActivity("work")).accepted)
    }
    func testPausedSessionNoCatchupAndRestStops() {
        let clock=FakeClock(); let engine=PetEngine(clock:clock,catalog:PetCatalog(activities:[testWork()]))
        _=engine.perform(.startActivity("work"));clock.now=7200;engine.tick();XCTAssertEqual(engine.state.activity?.elapsedSeconds,0)
        _=engine.send(.toggleRest);XCTAssertNil(engine.state.activity);XCTAssertTrue(engine.state.resting)
    }
    func testStateFailureAtCompletionAndLargeTick() {
        var state=PetState();state.strength=0;state.food=0;state.drink=0;state.health=30.01
        let clock=FakeClock();let engine=PetEngine(state:state,clock:clock,random:FixedRandom(),catalog:PetCatalog(activities:[testWork(seconds:15)]))
        XCTAssertTrue(engine.perform(.startActivity("work")).accepted)
        clock.now=15;engine.tick();XCTAssertNil(engine.state.activity)
        if case .activityStopped(_,let reason,_,let bonus)=engine.drainEvents().last { XCTAssertEqual(reason,.stateFailed);XCTAssertEqual(bonus,0) } else { XCTFail("Missing stop") }
        let another=FakeClock();let normal=PetEngine(clock:another,random:FixedRandom(),catalog:PetCatalog(activities:[testWork(seconds:15)]))
        _=normal.perform(.startActivity("work"));another.now=30;normal.tick()
        XCTAssertEqual(normal.state.money,100.748,accuracy:1e-8)
        _=normal.perform(.startActivity("work"));_=normal.perform(.pauseActivity);another.now=45;normal.tick()
        XCTAssertEqual(normal.state.activity?.elapsedSeconds,0)
        _=normal.perform(.resumeActivity);another.now=60;normal.tick();XCTAssertEqual(normal.state.activity?.elapsedSeconds,15)
    }
    func testSixtyThresholdAfterConsumption() {
        for (input,expected) in [(62.4,100.52),(62.6,100.68)] {
            var state=PetState();state.food=input;state.drink=input
            let clock=FakeClock();let engine=PetEngine(state:state,clock:clock,random:FixedRandom(),catalog:PetCatalog(activities:[testWork()]))
            _=engine.perform(.startActivity("work"));clock.now=15;engine.tick()
            XCTAssertEqual(engine.state.money,expected,accuracy:1e-8)
        }
    }
    func testLowThresholdsAndStateFailureWins() {
        var state=PetState();state.strength=0;state.food=25;state.drink=25;state.health=61
        let clock=FakeClock();let engine=PetEngine(state:state,clock:clock,random:FixedRandom(),catalog:PetCatalog(activities:[testWork()]))
        _=engine.perform(.startActivity("work"));clock.now=15;engine.tick()
        XCTAssertEqual(engine.state.money,100.12,accuracy:1e-8)
        XCTAssertEqual(engine.state.food,24.9125,accuracy:1e-8);XCTAssertEqual(engine.state.drink,24.9375,accuracy:1e-8)
    }
}
