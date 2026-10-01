import XCTest
@testable import PetCore
final class PetEconomyIntegrationTests: XCTestCase {
    func testOriginalStyleEconomyRoundTrip() throws {
        let item=ItemDefinition(id:"bread",name:"面包",price:8,food:30)
        let catalog=PetCatalog(activities:[testWork(seconds:15)],items:[item])
        let clock=FakeClock();var initial=PetState();initial.food=50
        let engine=PetEngine(state:initial,clock:clock,random:FixedRandom(),catalog:catalog)
        XCTAssertTrue(engine.perform(.startActivity("work")).accepted)
        clock.now=15;engine.tick();clock.now=16;engine.tick()
        let earned=engine.state.money-1000;XCTAssertGreaterThan(earned,0)
        XCTAssertTrue(engine.perform(.buyItem("bread",mode:.inventory)).accepted)
        let food=engine.state.food;XCTAssertEqual(engine.state.inventory["bread"],1)
        XCTAssertTrue(engine.perform(.useItem("bread")).accepted)
        XCTAssertGreaterThan(engine.state.food,food);XCTAssertEqual(engine.state.inventory["bread",default:0],0)
        XCTAssertEqual(engine.state.money,1000+earned-8,accuracy:1e-8)
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let store=PetSaveStore(directory:dir);try store.save(engine.state)
        XCTAssertEqual(try store.load(),engine.state)
    }
    func testSaveFailureDoesNotRepeatCommandAndUnknownRetained() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        try Data("blocked".utf8).write(to:dir)
        var state=PetState();state.inventory["unknown"]=2
        let engine=PetEngine(state:state,catalog:PetCatalog(items:[ItemDefinition(id:"bread",name:"面包",price:8)]))
        _=engine.perform(.buyItem("bread",mode:.inventory));let purchased=engine.state
        let store=PetSaveStore(directory:dir)
        XCTAssertThrowsError(try store.save(engine.state));XCTAssertThrowsError(try store.save(engine.state))
        XCTAssertEqual(engine.state,purchased);XCTAssertFalse(engine.perform(.useItem("unknown")).accepted)
        XCTAssertEqual(engine.state.inventory["unknown"],2)
    }
    func testPresentationRestoresActivityWithoutSettling() {
        var state=PetState();state.activity=ActivitySession(activityID:"work")
        let catalog=PetCatalog(activities:[testWork()])
        XCTAssertEqual(PetPresentation(state:state,catalog:catalog).graphID,"workone")
        state.activity?.isPaused=true;XCTAssertNil(PetPresentation(state:state,catalog:catalog).graphID)
        state.activity=nil;state.resting=true
        XCTAssertEqual(PetPresentation(state:state,catalog:catalog).action,.sleep)
        XCTAssertEqual(state.money,1000)
    }
    func testUnknownPausedActivitySurvivesIllnessAndItemUse() {
        let clock=FakeClock(); var state=PetState();state.health=10
        var session=ActivitySession(activityID:"unknown");session.isPaused=true;session.elapsedSeconds=123;session.earned=45;state.activity=session
        let catalog=PetCatalog(items:[ItemDefinition(id:"item",name:"测试",price:0)])
        let engine=PetEngine(state:state,clock:clock,random:FixedRandom(),catalog:catalog)
        clock.now=15;engine.tick();XCTAssertEqual(engine.state.activity,session)
        let second=PetEngine(state:state,catalog:catalog)
        _=second.perform(.buyItem("item",mode:.useImmediately));XCTAssertEqual(second.state.activity,session)
        XCTAssertFalse(second.drainEvents().contains { if case .activityStopped = $0 { true } else { false } })
        XCTAssertFalse(engine.drainEvents().contains { if case .activityStopped = $0 { true } else { false } })
        _=engine.perform(.stopActivity);XCTAssertNil(engine.state.activity)
    }
    func testActivityDecisionInformation() {
        let work=testWork();let details=work.decisionDescription
        for value in ["金币","0.68","饱腹","0.175","饮水","0.125","心情"] { XCTAssertTrue(details.contains(value),value) }
        XCTAssertTrue(testWork(kind:.study).decisionDescription.contains("经验"))
    }
}
