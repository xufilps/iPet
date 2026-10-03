// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetToolbarVisibilityTests:XCTestCase {
    func testInitialGraceAndHoverRestore() {
        var state=PetToolbarVisibility()
        XCTAssertTrue(state.update(now:0,autoHide:true,hovered:false,menuTracking:false))
        XCTAssertTrue(state.update(now:3.999,autoHide:true,hovered:false,menuTracking:false))
        XCTAssertFalse(state.update(now:4,autoHide:true,hovered:false,menuTracking:false))
        XCTAssertTrue(state.update(now:10,autoHide:true,hovered:true,menuTracking:false))
        XCTAssertTrue(state.update(now:30,autoHide:true,hovered:true,menuTracking:false))
        XCTAssertTrue(state.update(now:31,autoHide:true,hovered:false,menuTracking:false))
        XCTAssertFalse(state.update(now:35,autoHide:true,hovered:false,menuTracking:false))
    }
    func testMenuHoldsUntilFourSecondsAfterEnd() {
        var state=PetToolbarVisibility()
        _=state.update(now:0,autoHide:true,hovered:false,menuTracking:false)
        XCTAssertTrue(state.update(now:2,autoHide:true,hovered:false,menuTracking:true))
        XCTAssertTrue(state.update(now:100,autoHide:true,hovered:false,menuTracking:true))
        XCTAssertTrue(state.update(now:101,autoHide:true,hovered:false,menuTracking:false))
        XCTAssertFalse(state.update(now:105,autoHide:true,hovered:false,menuTracking:false))
    }
    func testBriefInteractionRestartsDeadlineBeforeNextPeriodicRefresh() {
        for menu in [false,true] {
            var state=PetToolbarVisibility()
            _=state.update(now:0,autoHide:true,hovered:false,menuTracking:false)
            _=state.update(now:3.9,autoHide:true,hovered:!menu,menuTracking:menu)
            _=state.update(now:3.95,autoHide:true,hovered:false,menuTracking:false)
            XCTAssertTrue(state.update(now:4.1,autoHide:true,hovered:false,menuTracking:false))
            XCTAssertFalse(state.update(now:7.95,autoHide:true,hovered:false,menuTracking:false))
        }
    }
    func testDisabledResetAndClockReversal() {
        var state=PetToolbarVisibility()
        _=state.update(now:10,autoHide:true,hovered:false,menuTracking:false)
        XCTAssertFalse(state.update(now:14,autoHide:true,hovered:false,menuTracking:false))
        XCTAssertTrue(state.update(now:15,autoHide:false,hovered:false,menuTracking:false))
        XCTAssertTrue(state.update(now:50,autoHide:true,hovered:false,menuTracking:false))
        state.reset()
        XCTAssertTrue(state.update(now:100,autoHide:true,hovered:false,menuTracking:false))
        XCTAssertTrue(state.update(now:1,autoHide:true,hovered:false,menuTracking:false))
        XCTAssertFalse(state.update(now:5,autoHide:true,hovered:false,menuTracking:false))
    }
}
