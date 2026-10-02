import XCTest
import PetCore
@testable import PetRendering
final class PetClimbTests:XCTestCase {
    func testRecoveryReturnsPartiallyClippedFramesToVisibleScreen() {
        let screen=CGRect(x:-1000,y:50,width:1000,height:900)
        XCTAssertEqual(PetClimbPlan.recovered(pet:CGRect(x:-1072.5,y:300,width:250,height:250),screen:screen),CGRect(x:-1000,y:300,width:250,height:250))
        XCTAssertEqual(PetClimbPlan.recovered(pet:CGRect(x:-92.5,y:850,width:250,height:250),screen:screen),CGRect(x:-250,y:700,width:250,height:250))
    }
    func testOriginalSideAnchorsAndMacYDirection() throws {
        let screen=CGRect(x:-1000,y:50,width:1000,height:900),pet=CGRect(x:-950,y:300,width:250,height:250)
        let up=try XCTUnwrap(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:pet,screen:screen))
        let located=up.located(pet:pet,screen:screen)
        XCTAssertEqual(located.minX,-1072.5);XCTAssertEqual(located.minY,300)
        XCTAssertEqual(up.advance(pet:located,screen:screen,seconds:0.125)?.minY,305)
        let rightPet=CGRect(x:-300,y:300,width:250,height:250)
        let down=try XCTUnwrap(PetClimbPlan.make(left:false,up:false,mood:.normal,pet:rightPet,screen:screen))
        let right=down.located(pet:rightPet,screen:screen)
        XCTAssertEqual(right.minX,-92.5);XCTAssertEqual(down.advance(pet:right,screen:screen,seconds:0.125)?.minY,295)
    }
    func testTriggerCheckAndIllRejection() throws {
        let screen=CGRect(x:0,y:0,width:1000,height:800),pet=CGRect(x:50,y:400,width:250,height:250)
        XCTAssertNotNil(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:pet,screen:screen))
        XCTAssertNil(PetClimbPlan.make(left:true,up:true,mood:.ill,pet:pet,screen:screen))
        XCTAssertNil(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:CGRect(x:51,y:400,width:250,height:250),screen:screen))
        XCTAssertNil(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:CGRect(x:50,y:451,width:250,height:250),screen:screen))
        let up=try XCTUnwrap(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:pet,screen:screen))
        let near=CGRect(x:-72.5,y:499,width:250,height:250)
        XCTAssertEqual(up.advance(pet:near,screen:screen,seconds:0.125)?.minY,500)
        XCTAssertNil(up.advance(pet:CGRect(x:-72.5,y:500,width:250,height:250),screen:screen,seconds:0.125))
    }
}
