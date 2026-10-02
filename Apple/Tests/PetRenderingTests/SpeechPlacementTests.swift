import XCTest
@testable import PetRendering
final class SpeechPlacementTests:XCTestCase {
    func testAboveBelowAndClampOnOffsetScreen() {
        let screen=CGRect(x:-1000,y:100,width:900,height:700),bubble=CGSize(width:264,height:100)
        let above=SpeechPlacement.frame(pet:CGRect(x:-600,y:200,width:280,height:280),bubble:bubble,screen:screen)
        XCTAssertEqual(above.minY,488)
        let below=SpeechPlacement.frame(pet:CGRect(x:-600,y:550,width:280,height:250),bubble:bubble,screen:screen)
        XCTAssertEqual(below.maxY,542)
        let edge=SpeechPlacement.frame(pet:CGRect(x:-1050,y:0,width:500,height:500),bubble:CGSize(width:1200,height:900),screen:screen)
        XCTAssertTrue(screen.contains(edge))
    }
}
