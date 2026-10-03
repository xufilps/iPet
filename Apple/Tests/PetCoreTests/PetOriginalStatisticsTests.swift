import XCTest
@testable import PetCore
final class PetOriginalStatisticsTests:XCTestCase {
    func testSamplingAndDisabledTimeAndTouchCounts() {
        let clock=FakeClock(),engine=PetEngine(clock:clock,random:FixedRandom())
        _=engine.send(.toggleRest);clock.now=15;engine.tick()
        XCTAssertEqual(engine.state.progress?.counters?["stat_total_time"],15)
        XCTAssertEqual(engine.state.progress?.counters?["stat_sleep_time"],15)
        engine.configureSimulation(enabled:false,fixedMood:.normal)
        _=engine.send(.touchHead);engine.recordPinchStart()
        _=engine.send(.touchPinch);_=engine.send(.touchPinch)
        clock.now=30;engine.tick();clock.now=1000;engine.tick()
        XCTAssertEqual(engine.state.progress?.counters?["stat_total_time"],15)
        XCTAssertEqual(engine.state.progress?.counters?["stat_touch_head"],2)
        XCTAssertEqual(engine.state.progress?.counters?["stat_touch_body"],1)
    }
    func testSourceFlagsAndConsumptionFaceValue() throws {
        var state=PetState();state.health=1;state.food=0;state.drink=0;state.feeling=0;state.strength=0;state.money=0;state.experience=100
        let clock=FakeClock(),engine=PetEngine(state:state,clock:clock,random:FixedRandom())
        clock.now=15;engine.tick()
        let counters=try XCTUnwrap(engine.state.progress?.counters)
        XCTAssertEqual(counters["stat_level"],Double(engine.state.level))
        for key in ["stat_ill_nomoney","stat_level_g_money","stat_0_feel","stat_0_f_sd","stat_0_all","stat_0_strengthfood","stat_0_strengthdrink","stat_0_sd_sf"] { XCTAssertEqual(counters[key],1,key) }
        state.health=30.01
        let transitionClock=FakeClock(),transition=PetEngine(state:state,clock:transitionClock,random:FixedRandom())
        transitionClock.now=15;transition.tick()
        XCTAssertEqual(transition.state.mood,.ill)
        XCTAssertNil(transition.state.progress?.counters?["stat_ill_nomoney"])
        transitionClock.now=30;transition.tick()
        XCTAssertEqual(transition.state.progress?.counters?["stat_ill_nomoney"],1)
        let item=ItemDefinition(id:"drug",name:"药品",category:.drug,price:10,experience:-5)
        var inventory=PetState();inventory.inventory["drug"]=2
        let consumer=PetEngine(state:inventory,catalog:PetCatalog(items:[item]),wallClock:FixedWallClock())
        _=consumer.useItems(id:"drug",count:2)
        XCTAssertEqual(consumer.state.progress?.spent,0)
        XCTAssertEqual(consumer.state.progress?.counters?["stat_betterbuy"],20)
        XCTAssertEqual(consumer.state.progress?.counters?["stat_bb_drug_exp"],-10)
        XCTAssertEqual(consumer.state.progress?.counters?["buy_drug"],2)
        try consumer.state.validate()
    }
    func testV3MigrationAndUnknownCounterRoundTrip() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let store=PetSaveStore(directory:root)
        var state=PetState();state.progress=PetProgress()
        var object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(PetSaveDocument(state:state))) as! [String:Any]
        object["version"]=3;let original=try JSONSerialization.data(withJSONObject:historicalSaveObject(object))
        try original.write(to:store.primary);state=try XCTUnwrap(store.load())
        XCTAssertNil(state.progress?.counters)
        state.progress?.counters=["unknown_metric":-3]
        try store.save(state)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),original)
        XCTAssertEqual(try store.load()?.progress?.counters?["unknown_metric"],-3)
        state.progress?.counters?["invalid"] = .infinity
        XCTAssertThrowsError(try state.validate())
    }

}
