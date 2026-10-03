// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetRendering
final class SpeechLayoutTests:XCTestCase {
    let screen=CGRect(x:-1000,y:0,width:1000,height:800)
    let pet=CGRect(x:-500,y:300,width:280,height:280)
    func testInsideAnchorsToPetBottom() {
        let frame=SpeechPlacement.frame(pet:pet,bubble:CGSize(width:264,height:120),screen:screen,mode:.inside)
        XCTAssertEqual(frame.minY,pet.minY);XCTAssertEqual(frame.midX,pet.midX)
    }
    func testOutsidePrefersBelowAndFallsBackAbove() {
        XCTAssertEqual(SpeechPlacement.frame(pet:pet,bubble:CGSize(width:264,height:120),screen:screen,mode:.outside).minY,172)
        let low=pet.offsetBy(dx:0,dy:-300)
        XCTAssertEqual(SpeechPlacement.frame(pet:low,bubble:CGSize(width:264,height:120),screen:screen,mode:.outside).minY,288)
    }
    func testViewportReflowsToNarrowScreenAndInsidePet() {
        let narrow=CGRect(x:0,y:0,width:160,height:200)
        let bounds=SpeechPlacement.textLimits(pet:CGRect(x:0,y:0,width:150,height:150),screen:narrow,mode:.inside)
        XCTAssertEqual(bounds.width,126);XCTAssertEqual(bounds.height,100)
        let outer=SpeechPlacement.textLimits(pet:pet,screen:narrow,mode:.outside)
        XCTAssertEqual(outer.width,136);XCTAssertEqual(outer.height,150)
    }
    func testInvalidScreenAndBubbleCannotProduceNaNFrames() {
        XCTAssertEqual(SpeechPlacement.frame(pet:pet,bubble:CGSize(width:264,height:120),screen:.null,mode:.inside),.zero)
        XCTAssertEqual(SpeechPlacement.frame(pet:pet,bubble:CGSize(width:Double.nan,height:120),screen:screen),.zero)
        XCTAssertEqual(SpeechPlacement.textLimits(pet:pet,screen:.zero,mode:.outside),.zero)
    }
}
