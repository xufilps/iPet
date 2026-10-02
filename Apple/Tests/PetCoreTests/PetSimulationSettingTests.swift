import XCTest
@testable import PetCore
final class PetSimulationSettingTests:XCTestCase {
    func testDisabledClockAndTouchesDoNotAdvanceOrCatchUp() throws {
        let clock=FakeClock();let engine=PetEngine(clock:clock,random:FixedRandom())
        engine.configureSimulation(enabled:false,fixedMood:.happy)
        let before=engine.state
        for time in 1...100 { clock.now=Double(time)*15;engine.tick() }
        _=engine.send(.touchHead);_=engine.send(.touchPinch)
        var attributes=engine.state;attributes.progress=before.progress
        XCTAssertEqual(attributes,before);XCTAssertEqual(engine.presentationMood,.happy)
        let paused=engine.state
        XCTAssertEqual(try JSONDecoder().decode(PetState.self,from:JSONEncoder().encode(engine.state)),paused)
        engine.configureSimulation(enabled:true,fixedMood:.ill)
        engine.tick();XCTAssertEqual(engine.state,paused)
        clock.now+=15;engine.tick();XCTAssertNotEqual(engine.state,before)
        XCTAssertEqual(engine.presentationMood,engine.state.mood)
    }
    func testDisabledPreviewStillAllowsExistingInventoryEffects() {
        var state=PetState();state.inventory["item"]=1;state.feeling=20;state.money=0
        let item=ItemDefinition(id:"item",name:"物品",price:1000,feeling:10)
        let engine=PetEngine(state:state,catalog:PetCatalog(items:[item]),wallClock:FixedWallClock())
        engine.configureSimulation(enabled:false,fixedMood:.normal)
        XCTAssertTrue(engine.perform(.buyItem("item",mode:.useImmediately)).accepted)
        XCTAssertEqual(engine.state,state);XCTAssertEqual(engine.drainEvents().count,1)
        XCTAssertTrue(engine.perform(.useItem("item")).accepted)
        XCTAssertEqual(engine.state.feeling,30);XCTAssertNil(engine.state.inventory["item"])
    }
    func testDisableStopsActivityWithoutCompletionBonus() {
        let work=ActivityDefinition(id:"work",name:"工作",graphID:"work",kind:.work,durationSeconds:60,moneyBase:10,strengthFood:1,strengthDrink:1,feeling:1,finishBonus:1)
        let engine=PetEngine(catalog:PetCatalog(activities:[work]))
        XCTAssertTrue(engine.perform(.startActivity("work")).accepted)
        let money=engine.state.money
        engine.configureSimulation(enabled:false,fixedMood:.normal)
        XCTAssertNil(engine.state.activity);XCTAssertFalse(engine.state.resting);XCTAssertEqual(engine.state.money,money)
        XCTAssertFalse(engine.perform(.startActivity("work")).accepted)
    }
    func testFixedMoodChangesTextModeWithoutChangingNumericBounds() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets")
        let catalog=try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json"))
        var entry=try XCTUnwrap(catalog.entries.first { $0.kind == "click" })
        entry.bounds=[:];entry.mode=1;entry.workState="Nomal";entry.working=nil;entry.dayTime=15
        let state=PetState()
        XCTAssertFalse(entry.matchesClick(state:state,activityName:nil,hour:12))
        XCTAssertTrue(entry.matchesClick(state:state,activityName:nil,hour:12,mood:.happy))
        entry.bounds=["foodmax":10]
        XCTAssertFalse(entry.matchesClick(state:state,activityName:nil,hour:12,mood:.happy))
    }

}
