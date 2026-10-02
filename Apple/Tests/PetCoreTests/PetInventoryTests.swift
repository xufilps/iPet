import XCTest
@testable import PetCore
final class PetInventoryTests:XCTestCase {
    let catalog=PetCatalog(items:[
        ItemDefinition(id:"b",name:"苹果",category:.snack,price:3),
        ItemDefinition(id:"a",name:"Water",category:.drink,price:2),
        ItemDefinition(id:"c",name:"茶",category:.drink,price:2)])
    let inventory=["a":3,"b":2,"c":3,"unknown":4,"zero":0]
    func testFiltersAndTotalsRemainIndependent() {
        let query=PetInventoryQuery(search:" water ",category:.drink,favoritesOnly:true)
        let result=query.evaluate(inventory:inventory,catalog:catalog,favorites:["a"])
        XCTAssertEqual(result.ids,["a"])
        XCTAssertEqual(result.totalCount,12);XCTAssertEqual(result.knownValue,18)
        XCTAssertEqual(result.unpricedCount,4)
    }
    func testSortsAndDeterministicTies() {
        for (sort,expected) in [(PetInventorySort.catalog,["b","a","c","unknown"]),(.quantity,["b","a","c","unknown"]),(.price,["unknown","a","c","b"]),(.name,["a","b","c","unknown"])] {
            XCTAssertEqual(PetInventoryQuery(sort:sort).evaluate(inventory:inventory,catalog:catalog).ids,expected)
        }
        XCTAssertEqual(PetInventoryQuery(sort:.price,ascending:false).evaluate(inventory:inventory,catalog:catalog).ids,["b","a","c","unknown"])
    }
    func testUnknownInventoryIsRetainedButNotPriced() {
        let result=PetInventoryQuery(search:"UNKNOWN").evaluate(inventory:inventory,catalog:catalog)
        XCTAssertEqual(result.ids,["unknown"]);XCTAssertEqual(result.unpricedCount,4)
        XCTAssertTrue(PetInventoryQuery(category:.drink).evaluate(inventory:inventory,catalog:catalog).ids.contains("a"))
        XCTAssertFalse(PetInventoryQuery(category:.drink).evaluate(inventory:inventory,catalog:catalog).ids.contains("unknown"))
    }
}
