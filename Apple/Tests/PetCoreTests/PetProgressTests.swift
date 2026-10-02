import XCTest
@testable import PetCore
final class PetProgressTests:XCTestCase {
    func testPurchasesAndInventoryUseCountOnlySuccessfulOperations() throws {
        let item=ItemDefinition(id:"item",name:"食物",price:8)
        let engine=PetEngine(catalog:PetCatalog(items:[item,ItemDefinition(id:"expensive",name:"昂贵物品",price:1000)]),wallClock:FixedWallClock())
        XCTAssertFalse(engine.perform(.useItem("item")).accepted)
        XCTAssertFalse(engine.perform(.buyItem("expensive",mode:.inventory)).accepted);XCTAssertNil(engine.state.progress)
        _=engine.perform(.buyItem("item",mode:.inventory));_=engine.perform(.useItem("item"))
        let progress=try XCTUnwrap(engine.state.progress)
        XCTAssertEqual(progress.purchased,1);XCTAssertEqual(progress.spent,8);XCTAssertEqual(progress.used,1)
        engine.configureSimulation(enabled:false,fixedMood:.normal)
        _=engine.perform(.buyItem("item",mode:.useImmediately))
        XCTAssertEqual(engine.state.progress,progress)
    }
    func testActivityTimePauseAndHistory() throws {
        let clock=FakeClock(),wall=FixedWallClock()
        let work=ActivityDefinition(id:"w",name:"工作",graphID:"work",kind:.work,durationSeconds:30,moneyBase:10,strengthFood:1,strengthDrink:1,feeling:1,finishBonus:0.5)
        let engine=PetEngine(clock:clock,random:FixedRandom(),catalog:PetCatalog(activities:[work]),wallClock:wall)
        _=engine.perform(.startActivity("w"));clock.now=15;engine.tick()
        _=engine.perform(.pauseActivity);clock.now=30;engine.tick()
        XCTAssertEqual(engine.state.progress?.workSeconds,15)
        _=engine.perform(.resumeActivity);clock.now=45;engine.tick();XCTAssertNotNil(engine.state.activity)
        clock.now=46;engine.tick()
        let history=try XCTUnwrap(engine.state.progress?.history.last)
        XCTAssertEqual(history.reason,.completed);XCTAssertEqual(history.seconds,30);XCTAssertEqual(history.date,wall.now)
        XCTAssertEqual(engine.state.progress?.workSeconds,30)
        XCTAssertEqual(engine.state.progress?.moneyEarned,(history.earned+history.bonus))
    }
    func testV2UpgradePreservesOriginalAndProgressRoundTrip() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let store=PetSaveStore(directory:root)
        var object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(PetSaveDocument(state:PetState()))) as! [String:Any]
        object["version"]=2
        let original=try JSONSerialization.data(withJSONObject:object);try original.write(to:store.primary)
        var state=try XCTUnwrap(store.load());XCTAssertNil(state.progress)
        state.progress=PetProgress();try store.save(state)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),original)
        XCTAssertEqual(try store.load(),state)
        let header=try JSONSerialization.jsonObject(with:Data(contentsOf:store.primary)) as! [String:Any]
        XCTAssertEqual(header["version"] as? Int,6)
        state.progress?.spent = .nan;XCTAssertThrowsError(try state.validate())
        let future=Data("{\"version\":7}".utf8);try future.write(to:store.primary)
        XCTAssertThrowsError(try store.load());XCTAssertEqual(try Data(contentsOf:store.primary),future)
    }
    func testHistoryIsBoundedAndManualEndsHaveNoBonus() throws {
        let work=ActivityDefinition(id:"w",name:"工作",graphID:"work",kind:.work,durationSeconds:30,moneyBase:10,strengthFood:1,strengthDrink:1,feeling:1,finishBonus:0.5)
        let engine=PetEngine(catalog:PetCatalog(activities:[work]),wallClock:FixedWallClock())
        for _ in 0..<201 { _=engine.perform(.startActivity("w"));_=engine.perform(.stopActivity) }
        let progress=try XCTUnwrap(engine.state.progress)
        XCTAssertEqual(progress.activityEnds,201);XCTAssertEqual(progress.history.count,200)
        XCTAssertEqual(progress.history.first?.id,2);XCTAssertEqual(progress.history.last?.id,201)
        XCTAssertEqual(progress.history.last?.reason,.manual);XCTAssertEqual(progress.history.last?.bonus,0)
        try engine.state.validate()
    }

}
