import XCTest
@testable import PetRendering
final class PetWindowBehaviorTests:XCTestCase {
    func testInputModesProtectGestureAndRespectFullPassThrough() {
        let automatic=PetWindowBehavior()
        XCTAssertTrue(automatic.ignoresMouse(interacting:false,opaque:false))
        XCTAssertFalse(automatic.ignoresMouse(interacting:false,opaque:true))
        XCTAssertFalse(automatic.ignoresMouse(interacting:true,opaque:false))
        let through=PetWindowBehavior(passThrough:true)
        for interacting in [false,true] { for opaque in [false,true] {
            XCTAssertTrue(through.ignoresMouse(interacting:interacting,opaque:opaque))
        } }
    }
    func testOpacityBoundariesAndInvalidPreferences() {
        XCTAssertEqual(PetWindowBehavior(opacity:0).opacity,0.05)
        XCTAssertEqual(PetWindowBehavior(opacity:2).opacity,1)
        XCTAssertEqual(PetWindowBehavior(opacity:0.6).opacity,0.6)
        XCTAssertEqual(PetWindowBehavior(opacity:.nan).opacity,1)
        XCTAssertEqual(PetWindowBehavior(opacity:.infinity).opacity,1)
        XCTAssertTrue(PetWindowBehavior().topMost);XCTAssertFalse(PetWindowBehavior().passThrough)
    }
}
