import XCTest
@testable import PetCore
final class PetBulkItemTests:XCTestCase {
    func testBatchEqualsSequentialUseIncludingDecayAndSave() throws {
        var state=PetState();state.inventory["item"]=6;state.feeling=20
        let item=ItemDefinition(id:"item",name:"食物",price:8,food:10,feeling:4,health:-2,experience:5)
        let catalog=PetCatalog(items:[item]),clock=FixedWallClock()
        let bulk=PetEngine(state:state,catalog:catalog,wallClock:clock)
        let single=PetEngine(state:state,catalog:catalog,wallClock:clock)
        XCTAssertEqual(bulk.useItems(id:"item",count:4).used,4)
        for _ in 0..<4 { XCTAssertTrue(single.perform(.useItem("item")).accepted) }
        XCTAssertEqual(bulk.state,single.state);XCTAssertEqual(bulk.drainEvents().count,4)
        XCTAssertEqual(try JSONDecoder().decode(PetState.self,from:JSONEncoder().encode(bulk.state)),bulk.state)
    }
    func testClampAndRejectPreserveInventory() {
        var state=PetState();state.inventory=["item":2,"unknown":3]
        let engine=PetEngine(state:state,catalog:PetCatalog(items:[ItemDefinition(id:"item",name:"物品",price:0)]))
        XCTAssertEqual(engine.useItems(id:"item",count:0).used,0)
        XCTAssertEqual(engine.useItems(id:"item",count:-1).used,0)
        XCTAssertEqual(engine.useItems(id:"unknown",count:1).used,0);XCTAssertEqual(engine.state,state)
        XCTAssertEqual(engine.useItems(id:"item",count:Int.max).used,2)
        XCTAssertNil(engine.state.inventory["item"]);XCTAssertEqual(engine.state.inventory["unknown"],3)
        XCTAssertEqual(engine.useItems(id:"item",count:1).used,0)
    }
}
