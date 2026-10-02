import XCTest
@testable import PetCore
final class PetActivityMultiplierTests:XCTestCase {
    private func source(_ kind:ActivityKind = .work) -> ActivityDefinition {
        switch kind {
        case .work: return testWork()
        case .study: return ActivityDefinition(id:"study",name:"学习",graphID:"study",kind:kind,durationSeconds:3600,moneyBase:80,strengthFood:2,strengthDrink:2,feeling:3,finishBonus:0.2)
        case .play: return ActivityDefinition(id:"play",name:"游戏",graphID:"play",kind:kind,durationSeconds:3600,moneyBase:18,strengthFood:1,strengthDrink:1.5,feeling:-1,finishBonus:0.2)
        }
    }
    func testOriginalDoubleFixedInputs() throws {
        for (kind,money,a,b,c) in [(ActivityKind.work,15.4,4.55,3.25,1.3),(.study,138.4,2.6,2.6,3.9),(.play,52.8,1.3,1.95,-1.3)] {
            let base=source(kind)
            XCTAssertEqual(base.multiplied(by:1),base)
            let work=try XCTUnwrap(base.multiplied(by:2))
            XCTAssertEqual(work.moneyBase,money,accuracy:1e-8)
            XCTAssertEqual(work.strengthFood,a,accuracy:1e-8);XCTAssertEqual(work.strengthDrink,b,accuracy:1e-8);XCTAssertEqual(work.feeling,c,accuracy:1e-8)
            XCTAssertEqual(work.levelLimit,20);XCTAssertEqual(work.durationSeconds,base.durationSeconds);XCTAssertEqual(work.finishBonus,base.finishBonus)
            XCTAssertEqual(work.graphID,base.graphID);XCTAssertEqual(work.id,base.id)
        }
    }
    func testOriginalMultiplierRangeAndRejectsInvalid() {
        let base=source()
        XCTAssertEqual(base.maximumMultiplier(level:1),1);XCTAssertEqual(base.maximumMultiplier(level:19),1)
        XCTAssertEqual(base.maximumMultiplier(level:20),2);XCTAssertEqual(base.maximumMultiplier(level:999999),400)
        XCTAssertEqual(testWork(level:5).maximumMultiplier(level:100),6)
        XCTAssertNil(base.multiplied(by:0));XCTAssertNil(base.multiplied(by:Int.max));XCTAssertNil(base.multiplied(by:401))
    }
    func testSignedPlayFallbackAndMinimumDuration() throws {
        var base=source(.play);base.feeling = -100;base.strengthFood=0;base.strengthDrink=0;base.durationSeconds=1
        let work=try XCTUnwrap(base.multiplied(by:2))
        XCTAssertEqual(work.moneyBase,18);XCTAssertEqual(work.strengthFood,1);XCTAssertEqual(work.strengthDrink,1.5)
        XCTAssertEqual(work.feeling,-1);XCTAssertEqual(work.levelLimit,0);XCTAssertEqual(work.finishBonus,0.2);XCTAssertEqual(work.durationSeconds,600)
        for kind in ActivityKind.allCases { XCTAssertNotNil(source(kind).multiplied(by:400)) }
        base.levelLimit=Int.max;XCTAssertNil(base.multiplied(by:2));XCTAssertEqual(base.maximumMultiplier(level:Int.max),1)
    }
    func testEngineUsesMultiplierAndPreservesSameActivityToggle() throws {
        var state=PetState();state.experience=36100 // level20
        let clock=FakeClock();let catalog=PetCatalog(activities:[source()]);let engine=PetEngine(state:state,clock:clock,random:FixedRandom(),catalog:catalog)
        XCTAssertTrue(engine.perform(.startMultipliedActivity("work",multiplier:2)).accepted)
        XCTAssertEqual(engine.state.activity?.effectiveMultiplier,2)
        clock.now=15;engine.tick()
        XCTAssertEqual(engine.state.money,1001.309,accuracy:1e-8)
        XCTAssertEqual(engine.state.food,99.84075,accuracy:1e-8);XCTAssertEqual(engine.state.drink,99.88625,accuracy:1e-8)
        let before=engine.state
        XCTAssertFalse(engine.perform(.startMultipliedActivity("work",multiplier:3)).accepted);XCTAssertEqual(engine.state,before)
        XCTAssertTrue(engine.perform(.startActivity("work")).accepted);XCTAssertNil(engine.state.activity)
        XCTAssertEqual(engine.state.progress?.history.last?.multiplier,2)
        XCTAssertFalse(PetEngine(catalog:catalog).perform(.startMultipliedActivity("work",multiplier:2)).accepted)
    }
    func testMultiplierCompletionAndResumeGate() throws {
        var base=source();base.durationSeconds=600
        var state=PetState();state.experience=36100
        let clock=FakeClock();let catalog=PetCatalog(activities:[base]);let engine=PetEngine(state:state,clock:clock,random:FixedRandom(),catalog:catalog)
        _=engine.perform(.startMultipliedActivity("work",multiplier:2))
        for second in stride(from:15,through:600,by:15) { clock.now=Double(second);engine.tick() }
        let earned=try XCTUnwrap(engine.state.activity?.earned),money=engine.state.money
        clock.now=601;engine.tick()
        XCTAssertEqual(engine.state.money,money+earned*0.1,accuracy:1e-8);XCTAssertNil(engine.state.activity)
        state.activity=ActivitySession(activityID:"work",multiplier:2);state.activity?.isPaused=true;state.experience=0
        let low=PetEngine(state:state,catalog:catalog)
        XCTAssertFalse(low.perform(.resumeActivity).accepted);XCTAssertTrue(low.state.activity!.isPaused)
    }
    func testResumeCannotBypassMultiplierRangeAfterFallback() {
        var base=source(.play);base.feeling = -100;base.strengthFood=0;base.strengthDrink=0
        var state=PetState();state.activity=ActivitySession(activityID:base.id,multiplier:2);state.activity?.isPaused=true
        let engine=PetEngine(state:state,catalog:PetCatalog(activities:[base]))
        XCTAssertFalse(engine.perform(.startMultipliedActivity(base.id,multiplier:2)).accepted)
        let before=engine.state
        XCTAssertFalse(engine.perform(.resumeActivity).accepted)
        XCTAssertEqual(engine.state,before)
    }
    func testSavingOverVersion4PreservesOriginalWithoutLoad() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
        let store=PetSaveStore(directory:dir)
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:store.exportSnapshot(PetState())) as? [String:Any]);object["version"]=4
        let old=try JSONSerialization.data(withJSONObject:object)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);try old.write(to:store.primary)
        try store.save(PetState())
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),old)
    }
    func testSaveVersion4MigrationAndMultiplierRoundTrip() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
        let store=PetSaveStore(directory:dir);var state=PetState();state.activity=ActivitySession(activityID:"unknown",multiplier:2)
        let current=try store.exportSnapshot(state)
        XCTAssertEqual(try JSONSerialization.jsonObject(with:current) as? [String:Any] != nil,true)
        XCTAssertEqual(try store.previewImport(current).activity?.effectiveMultiplier,2)
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:current) as? [String:Any]);object["version"]=4
        var saved=try XCTUnwrap(object["state"] as? [String:Any]);var session=try XCTUnwrap(saved["activity"] as? [String:Any]);session.removeValue(forKey:"multiplier");saved["activity"]=session;object["state"]=saved
        let legacy=try JSONSerialization.data(withJSONObject:object);try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);try legacy.write(to:store.primary)
        let loaded=try XCTUnwrap(store.load());XCTAssertEqual(loaded.activity?.effectiveMultiplier,1)
        try store.save(loaded)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),legacy)
        let header=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:store.primary)) as? [String:Any]);XCTAssertEqual(header["version"] as? Int,6)
        state.activity?.multiplier=401;XCTAssertThrowsError(try state.validate())
        try Data("{\"version\":7}".utf8).write(to:store.primary);XCTAssertThrowsError(try store.save(loaded))
    }
}
