import XCTest
@testable import PetRendering
final class CompanionPlacementTests:XCTestCase {
    func testToolbarPrefersBelowAndFallsBackAboveAtBottomEdge() {
        let screen=CGRect(x:-1000,y:50,width:1000,height:700),bubble=CGSize(width:264,height:100)
        let middle=SpeechPlacement.frame(pet:CGRect(x:-500,y:300,width:200,height:200),bubble:bubble,screen:screen,preferBelow:true)
        XCTAssertEqual(middle.minY,192);XCTAssertEqual(middle.midX,-400)
        let bottom=SpeechPlacement.frame(pet:CGRect(x:-200,y:50,width:150,height:150),bubble:bubble,screen:screen,preferBelow:true)
        XCTAssertEqual(bottom.minY,208);XCTAssertEqual(bottom.maxX,0)
    }
}
