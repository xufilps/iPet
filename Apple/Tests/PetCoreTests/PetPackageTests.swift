import XCTest
@testable import PetCore
final class PetPackageTests:XCTestCase {
    private func definition(_ kind:ActivityKind = .work,_ id:String="basic") -> PetPackageDefinition {
        PetPackageDefinition(id:id,name:"基础套餐",description:"测试",kind:kind,commission:0.2,unitPrice:1,levelRatio:1.25,durationDays:7)
    }
    private func state(money:Double=10000) -> PetState { var s=PetState();s.experience=36100;s.money=money;return s }
    func testQuoteAndManualAffordabilityAndLevel() throws {
        let wall=FixedWallClock(),definition=definition(),catalog=PetCatalog(packages:[definition])
        let quote=try XCTUnwrap(definition.quote(level:15,now:wall.now))
        XCTAssertEqual(quote.price,2900);XCTAssertEqual(quote.level,12);XCTAssertEqual(quote.endTime,wall.now.addingTimeInterval(7*86400))
        let engine=PetEngine(state:state(money:2900),catalog:catalog,wallClock:wall)
        XCTAssertTrue(engine.perform(.signPackage("basic",level:15,replace:false)).accepted)
        XCTAssertEqual(engine.state.money,0);XCTAssertEqual(engine.state.workPackage,quote)
        for level in [10,16,25,Int.max] {
            let e=PetEngine(state:state(),catalog:catalog,wallClock:wall);let before=e.state
            XCTAssertFalse(e.perform(.signPackage("basic",level:level,replace:false)).accepted);XCTAssertEqual(e.state,before)
        }
        let poor=PetEngine(state:state(money:2899),catalog:catalog,wallClock:wall)
        XCTAssertFalse(poor.perform(.signPackage("basic",level:15,replace:false)).accepted)
    }
    func testReplacementRequiresConfirmationAndOriginalRefund() throws {
        let wall=FixedWallClock(),catalog=PetCatalog(packages:[definition()]),engine=PetEngine(state:state(),catalog:catalog,wallClock:wall)
        _=engine.perform(.signPackage("basic",level:15,replace:false));let before=engine.state
        XCTAssertFalse(engine.perform(.signPackage("basic",level:15,replace:false)).accepted);XCTAssertEqual(engine.state,before)
        // Original uses authorized12 to quote2300, remaining7/2=3.5; refund1150.
        XCTAssertTrue(engine.perform(.signPackage("basic",level:15,replace:true)).accepted)
        XCTAssertEqual(engine.state.money,5350)
        var poor=before;poor.money=2000
        let insufficient=PetEngine(state:poor,catalog:catalog,wallClock:wall)
        XCTAssertFalse(insufficient.perform(.signPackage("basic",level:15,replace:true)).accepted);XCTAssertEqual(insufficient.state,poor)
    }
    func testRenewalStrictBoundaryLevelDecayAndFlagReset() throws {
        let wall=FixedWallClock(),catalog=PetCatalog(packages:[definition()])
        var old=try XCTUnwrap(definition().quote(level:15,now:wall.now));old.autoRenew=true
        wall.now=old.endTime
        var saved=state(money:2300);saved.workPackage=old
        let equal=PetEngine(state:saved,catalog:catalog,wallClock:wall);saved=equal.state
        _=equal.perform(.renewPackages);XCTAssertEqual(equal.state,saved)
        saved.money=2300.01
        let enough=PetEngine(state:saved,catalog:catalog,wallClock:wall)
        XCTAssertTrue(enough.perform(.renewPackages).accepted)
        XCTAssertEqual(enough.state.money,0.01,accuracy:1e-8);XCTAssertEqual(enough.state.workPackage?.level,9)
        XCTAssertEqual(enough.state.workPackage?.autoRenew,false)
        XCTAssertEqual(enough.state.workPackage?.endTime,wall.now.addingTimeInterval(7*86400))
        let once=enough.state;_=enough.perform(.renewPackages);XCTAssertEqual(enough.state,once)
    }
    func testToggleChecksBothPackagesInOriginalOrder() throws {
        let wall=FixedWallClock(),catalog=PetCatalog(packages:[definition(),definition(.study,"school")])
        var saved=state(money:4000)
        saved.workPackage=try definition().quote(level:15,now:wall.now)
        saved.studyPackage=try definition(.study,"school").quote(level:15,now:wall.now)
        saved.workPackage?.autoRenew=true;saved.studyPackage?.autoRenew=true
        wall.now=saved.workPackage!.endTime
        let engine=PetEngine(state:saved,catalog:catalog,wallClock:wall)
        _=engine.perform(.setPackageAutoRenew(.study,enabled:true))
        XCTAssertEqual(engine.state.money,1700);XCTAssertFalse(engine.state.workPackage!.autoRenew)
        XCTAssertTrue(engine.state.studyPackage!.autoRenew);XCTAssertEqual(engine.state.studyPackage!.endTime,saved.studyPackage!.endTime)
    }
    func testUnknownContractAndNoOfflineAutomaticCharges() throws {
        let wall=FixedWallClock(),clock=FakeClock();var saved=state()
        saved.workPackage=try definition().quote(level:15,now:wall.now);saved.workPackage?.autoRenew=true
        wall.now=saved.workPackage!.endTime.addingTimeInterval(100)
        let engine=PetEngine(state:saved,clock:clock,catalog:PetCatalog(),wallClock:wall);saved=engine.state
        clock.now=7200;engine.tick();XCTAssertEqual(engine.state,saved)
        _=engine.perform(.renewPackages);XCTAssertEqual(engine.state,saved)
        XCTAssertFalse(engine.perform(.setPackageAutoRenew(.play,enabled:true)).accepted)
    }
    func testRefundNearExpiryAndUnknownReplacement() throws {
        let wall=FixedWallClock(),base=definition(),catalog=PetCatalog(packages:[base])
        var old=try XCTUnwrap(base.quote(level:15,now:wall.now))
        XCTAssertEqual(PetPackageRules.refund(contract:old,catalog:catalog,now:old.endTime.addingTimeInterval(-86400)),0)
        XCTAssertEqual(PetPackageRules.refund(contract:old,catalog:catalog,now:old.endTime.addingTimeInterval(-2*86400)),2300*6/7,accuracy:1e-8)
        old.definitionID="unknown";var saved=state();saved.workPackage=old
        let engine=PetEngine(state:saved,catalog:catalog,wallClock:wall)
        let response=engine.perform(.signPackage("basic",level:15,replace:true))
        XCTAssertTrue(response.accepted);XCTAssertTrue(response.message.contains("未识别"));XCTAssertEqual(engine.state.money,7100)
    }
    func testZeroAuthorizedRenewalNeverCreditsMoney() throws {
        let wall=FixedWallClock();var saved=state()
        saved.workPackage=try XCTUnwrap(definition().quote(level:1,now:wall.now));saved.workPackage?.autoRenew=true
        XCTAssertEqual(saved.workPackage?.level,0);wall.now=saved.workPackage!.endTime
        let engine=PetEngine(state:saved,catalog:PetCatalog(packages:[definition()]),wallClock:wall);saved=engine.state
        _=engine.perform(.renewPackages);XCTAssertEqual(engine.state,saved)
    }
    func testInvalidContractRejectedAndOldCatalogDecode() throws {
        var saved=state();saved.workPackage=try definition().quote(level:15,now:Date());saved.workPackage?.price = -1
        XCTAssertThrowsError(try saved.validate())
        XCTAssertThrowsError(try PetCatalog(packages:[definition(.play)]).validate())
        let old=try JSONDecoder().decode(PetCatalog.self,from:Data("{\"version\":1,\"activities\":[],\"items\":[]}".utf8))
        XCTAssertTrue(old.packageDefinitions.isEmpty)
        XCTAssertNil(definition().quote(level:0,now:Date()));XCTAssertNil(definition().quote(level:Int.max,now:Date()))
    }
    func testSaveSixRoundTripAndVersionFiveOriginal() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
        let store=PetSaveStore(directory:dir);var saved=state();saved.workPackage=try definition().quote(level:15,now:Date(timeIntervalSince1970:1000000))
        let data=try store.exportSnapshot(saved);XCTAssertEqual(try store.previewImport(data),saved)
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:store.exportSnapshot(state())) as? [String:Any]);object["version"]=5
        let legacy=try JSONSerialization.data(withJSONObject:historicalSaveObject(object));try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);try legacy.write(to:store.primary)
        let loaded=try XCTUnwrap(store.load());XCTAssertNil(loaded.workPackage)
        try store.save(loaded);XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),legacy)
        let header=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:store.primary)) as? [String:Any]);XCTAssertEqual(header["version"] as? Int,9)
        let future=Data("{\"version\":10}".utf8);try future.write(to:store.primary)
        XCTAssertThrowsError(try store.save(saved));XCTAssertEqual(try Data(contentsOf:store.primary),future)
    }
}
