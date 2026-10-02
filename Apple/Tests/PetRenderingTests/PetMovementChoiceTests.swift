import XCTest
import PetCore
@testable import PetRendering
final class PetMovementChoiceTests:XCTestCase {
    let screen=CGRect(x:0,y:0,width:1000,height:800)
    let pet=CGRect(x:400,y:300,width:250,height:250)
    func testOriginalMoodPoolsIncludePoorRegularWalking() {
        let normal=PetMovementChoice.candidates(mood:.normal,pet:pet,screen:screen)
        XCTAssertEqual(Set(normal.map(\.graphID)),Set(["walk.left","walk.right","crawl.left","crawl.right","fall.left","fall.right"]))
        let poor=PetMovementChoice.candidates(mood:.poor,pet:pet,screen:screen)
        XCTAssertEqual(poor.count,8)
        XCTAssertTrue(poor.contains { $0.graphID == "walk.left" })
        XCTAssertTrue(poor.contains { $0.graphID == "walk.left.slow" })
        let happy=PetMovementChoice.candidates(mood:.happy,pet:pet,screen:screen)
        XCTAssertEqual(happy.count,6)
        XCTAssertFalse(happy.contains { $0.graphID == "walk.left" })
        XCTAssertTrue(PetMovementChoice.candidates(mood:.ill,pet:pet,screen:screen).isEmpty)
    }
    func testAxisScoreAllowsOrthogonalAndBalancedVectors() {
        XCTAssertEqual(PetMovementChoice.score(x:-14,y:0,nextX:0,nextY:10),0)
        XCTAssertEqual(PetMovementChoice.score(x:-14,y:0,nextX:14,nextY:-10),-1)
        XCTAssertEqual(PetMovementChoice.score(x:-14,y:-10,nextX:14,nextY:-10),0)
        XCTAssertEqual(PetMovementChoice.score(x:-14,y:-10,nextX:0,nextY:10),-1)
        XCTAssertEqual(PetMovementChoice.score(x:-14,y:-10,nextX:-10,nextY:0),1)
    }
    func testWalkingAtBoundaryCanTurnOntoEitherVerticalWallDirection() throws {
        let previous=try XCTUnwrap(PetMovementChoice.candidates(mood:.normal,pet:pet,screen:screen).first { $0.graphID == "walk.left" })
        let pool=previous.compatible(mood:.normal,pet:CGRect(x:50,y:300,width:250,height:250),screen:screen)
        XCTAssertEqual(pool.count,2)
        XCTAssertTrue(pool.allSatisfy { $0.graphID == "climb.left" })
        XCTAssertEqual(Set(pool.map(\.speedY)),Set([-10.0,10.0]))
    }
    func testPartiallyClippedTopCanContinueToHorizontalAndFall() throws {
        let frame=CGRect(x:400,y:625,width:250,height:250)
        let top=try XCTUnwrap(PetMovementChoice.candidates(mood:.normal,pet:frame,screen:screen).first { $0.graphID == "climb.top.left" })
        let pool=top.compatible(mood:.normal,pet:frame,screen:screen)
        XCTAssertTrue(pool.contains { $0.graphID == "walk.left" })
        XCTAssertTrue(pool.contains { $0.graphID == "fall.left" })
        XCTAssertFalse(pool.contains { $0.graphID == "walk.right" })
    }
    func testTopCornerCanTurnDownWallWithoutRepositioning() throws {
        let initial=CGRect(x:400,y:625,width:250,height:250)
        let top=try XCTUnwrap(PetMovementChoice.candidates(mood:.normal,pet:initial,screen:screen).first { $0.graphID == "climb.top.left" })
        let corner=CGRect(x:50,y:625,width:250,height:250)
        let pool=top.compatible(mood:.normal,pet:corner,screen:screen)
        let choice=try XCTUnwrap(pool.first { $0.graphID == "climb.left" && $0.speedY<0 })
        if case .traversal(let plan)=choice {
            XCTAssertEqual(plan.located(pet:corner,screen:screen).minY,625)
            XCTAssertEqual(plan.advance(pet:plan.located(pet:corner,screen:screen),screen:screen,seconds:0.125)?.minY,620)
        } else { XCTFail("Expected downward wall traversal") }
    }

}
