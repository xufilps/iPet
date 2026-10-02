import XCTest
@testable import PetCore
final class PetActivityQueryTests:XCTestCase {
    private func activity(_ id:String,_ name:String,_ kind:ActivityKind,_ duration:Double,_ level:Int) -> ActivityDefinition {
        ActivityDefinition(id:id,name:name,graphID:"test",kind:kind,durationSeconds:duration,levelLimit:level,moneyBase:1,strengthFood:1,strengthDrink:1,feeling:1,finishBonus:0)
    }
    private var catalog:PetCatalog { PetCatalog(activities:[activity("c","阅读",.study,180,2),activity("b","Water Work",.work,120,0),activity("a","Water Play",.play,120,0)]) }
    func testCombinedFiltersAndEmptyResults() {
        XCTAssertEqual(PetActivityQuery(search:" water ",kind:.work,favoritesOnly:true).evaluate(catalog:catalog,favorites:["b","unknown"]).map(\.id),["b"])
        XCTAssertTrue(PetActivityQuery(kind:.study,favoritesOnly:true).evaluate(catalog:catalog,favorites:["b"]).isEmpty)
        XCTAssertTrue(PetActivityQuery(search:"不存在").evaluate(catalog:catalog).isEmpty)
        XCTAssertEqual(PetActivityQuery(favoritesOnly:true).evaluate(catalog:catalog,favorites:["a","unknown"]).map(\.id),["a"])
    }
    func testSortDirectionsAndStableTies() {
        for (sort,forward,reverse) in [(PetActivitySort.catalog,["c","b","a"],["a","b","c"]),(.name,["a","b","c"],["c","b","a"]),(.duration,["a","b","c"],["c","a","b"]),(.level,["a","b","c"],["c","a","b"])] {
            XCTAssertEqual(PetActivityQuery(sort:sort).evaluate(catalog:catalog).map(\.id),forward)
            XCTAssertEqual(PetActivityQuery(sort:sort,ascending:false).evaluate(catalog:catalog).map(\.id),reverse)
        }
    }
    func testQueryLeavesCatalogAndCurrentSessionUntouched() {
        let source=catalog
        _=PetActivityQuery(search:"work",sort:.duration,ascending:false).evaluate(catalog:source)
        XCTAssertEqual(source,catalog)
        XCTAssertEqual(PetActivityQuery().evaluate(catalog:source),source.activities)
        XCTAssertTrue(PetActivityQuery().evaluate(catalog:PetCatalog()).isEmpty)
    }
}
