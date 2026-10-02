import XCTest
import PetCore
@testable import PetRendering
final class PetWalkTests:XCTestCase {
    func testCompatibleSubsetNeverReversesAtTheEdge() throws {
        let screen=CGRect(x:0,y:0,width:1000,height:800),pet=CGRect(x:400,y:50,width:250,height:250)
        let plan=try XCTUnwrap(PetWalkPlan.make(left:true,crawl:false,mood:.normal,pet:pet,screen:screen))
        let pool=plan.compatible(mood:.normal,pet:pet,screen:screen)
        XCTAssertEqual(Set(pool.map(\.graphID)),Set(["walk.left","crawl.left"]))
        XCTAssertTrue(pool.allSatisfy { $0.action == .walkLeft })
        XCTAssertTrue(plan.compatible(mood:.normal,pet:CGRect(x:50,y:50,width:250,height:250),screen:screen).isEmpty)
    }
    func testBlockedDirectionReversesOrRejectsNarrowScreen() throws {
        let screen=CGRect(x:-1000,y:50,width:1000,height:800),pet=CGRect(x:-950,y:100,width:250,height:250)
        let plan=try XCTUnwrap(PetWalkPlan.make(left:true,crawl:false,mood:.normal,pet:pet,screen:screen))
        XCTAssertEqual(plan.action,.walkRight);XCTAssertEqual(plan.graphID,"walk.right")
        XCTAssertNil(PetWalkPlan.make(left:true,crawl:false,mood:.normal,pet:pet,screen:CGRect(x:-950,y:50,width:300,height:500)))
        XCTAssertNil(PetWalkPlan.make(left:false,crawl:true,mood:.ill,pet:pet,screen:screen))
    }
    func testOriginalSpeedScalesAndStopsAtCheckMargin() throws {
        let screen=CGRect(x:0,y:0,width:1000,height:800),pet=CGRect(x:500,y:100,width:250,height:250)
        let plan=try XCTUnwrap(PetWalkPlan.make(left:true,crawl:false,mood:.happy,pet:pet,screen:screen))
        XCTAssertEqual(plan.graphID,"walk.left.faster")
        XCTAssertEqual(plan.advance(pet:pet,screen:screen,seconds:0.125)?.minX,490)
        let near=CGRect(x:51,y:100,width:250,height:250)
        XCTAssertEqual(plan.advance(pet:near,screen:screen,seconds:0.125)?.minX,50)
        XCTAssertNil(plan.advance(pet:CGRect(x:50,y:100,width:250,height:250),screen:screen,seconds:0.125))
        XCTAssertNil(plan.advance(pet:pet,screen:screen,seconds:.nan))
        let crawl=try XCTUnwrap(PetWalkPlan.make(left:true,crawl:true,mood:.normal,pet:pet,screen:screen))
        XCTAssertEqual(crawl.graphID,"crawl.left");XCTAssertEqual(crawl.advance(pet:pet,screen:screen,seconds:0.125)?.minX,495)
    }
}
