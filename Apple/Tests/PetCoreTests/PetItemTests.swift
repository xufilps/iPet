import XCTest
@testable import PetCore
final class FixedWallClock: PetWallClock { var now=Date(timeIntervalSince1970:1_000_000) }
final class PetItemTests: XCTestCase {
    func testCreditSpecialGateAndInventory() {
        var state=PetState();state.money=0
        let cheap=ItemDefinition(id:"cheap",name:"饮料",price:8,drink:30)
        let expensive=ItemDefinition(id:"expensive",name:"贵物品",price:1000)
        let engine=PetEngine(state:state,catalog:PetCatalog(items:[cheap,expensive]))
        XCTAssertTrue(engine.perform(.buyItem("cheap",mode:.inventory)).accepted)
        XCTAssertEqual(engine.state.money,-8);XCTAssertEqual(engine.state.inventory["cheap"],1)
        XCTAssertTrue(engine.perform(.useItem("cheap")).accepted);XCTAssertNil(engine.state.inventory["cheap"])
        let before=engine.state;XCTAssertFalse(engine.perform(.useItem("cheap")).accepted);XCTAssertEqual(engine.state,before)
        let equal=PetEngine(catalog:PetCatalog(items:[expensive]));XCTAssertFalse(equal.perform(.buyItem("expensive",mode:.useImmediately)).accepted)
        state.money=1000.01;let enough=PetEngine(state:state,catalog:PetCatalog(items:[expensive]));XCTAssertTrue(enough.perform(.buyItem("expensive",mode:.inventory)).accepted)
    }
    func testBuffAndEmergencyDrug() throws {
        let wall=FixedWallClock();var state=PetState();state.health=10
        let drug=ItemDefinition(id:"drug",name:"太阳系",category:.drug,price:0,strength:-100,health:50,affection:-4,experience:-180)
        let engine=PetEngine(state:state,catalog:PetCatalog(items:[drug]),wallClock:wall)
        XCTAssertTrue(engine.perform(.buyItem("drug",mode:.useImmediately)).accepted)
        XCTAssertEqual(engine.state.experience,-180);XCTAssertEqual(engine.state.strength,50)
        XCTAssertEqual(engine.state.storedStrength,-50);XCTAssertEqual(engine.state.health,60);try engine.state.validate()
        XCTAssertEqual(engine.state.itemCooldowns["drug"],wall.now.addingTimeInterval(2.8*3600))
        XCTAssertEqual(PetItemRules.multiplier(category:.food,expiry:wall.now.addingTimeInterval(18000),now:wall.now),0.5)
        XCTAssertEqual(PetItemRules.multiplier(category:.gift,expiry:wall.now.addingTimeInterval(18000),now:wall.now),0.75)
    }
    func testRepeatedCommandsNegativeEffectsAndRollback() {
        let wall=FixedWallClock();var state=PetState();state.feeling=40;state.itemCooldowns["item"]=wall.now.addingTimeInterval(18000)
        let item=ItemDefinition(id:"item",name:"礼物",category:.gift,price:0,strength:-4,food:10,drink:10,feeling:20,health:-4,affection:4,experience:8)
        let engine=PetEngine(state:state,catalog:PetCatalog(items:[item]),wallClock:wall)
        _=engine.perform(.buyItem("item",mode:.useImmediately))
        XCTAssertEqual(engine.state.strength,98.5);XCTAssertEqual(engine.state.storedFood,3.75)
        XCTAssertEqual(engine.state.feeling,55);XCTAssertEqual(engine.state.health,97);XCTAssertEqual(engine.state.experience,6)
        XCTAssertEqual(engine.drainEvents().count,1)
        XCTAssertFalse(engine.perform(.buyItem("missing",mode:.inventory)).accepted)
        var full=PetState();full.inventory["item"]=1000000
        let blocked=PetEngine(state:full,catalog:PetCatalog(items:[item]));full=blocked.state;XCTAssertFalse(blocked.perform(.buyItem("item",mode:.inventory)).accepted);XCTAssertEqual(blocked.state,full)
    }
    func testAllRealItemsCanApplyAndValidate() throws {
        let apple=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog=try PetCatalog.load(from:apple.appendingPathComponent("Resources/PetAssets/gameplay.json"))
        for item in catalog.items {
            var state=PetState();state.money=1_000_000;state.health=50;state.food=40;state.drink=40
            let engine=PetEngine(state:state,catalog:catalog,wallClock:FixedWallClock())
            XCTAssertTrue(engine.perform(.buyItem(item.id,mode:.useImmediately)).accepted,item.name)
            try engine.state.validate()
        }
    }
}
