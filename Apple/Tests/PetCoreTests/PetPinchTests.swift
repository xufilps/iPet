import XCTest
@testable import PetCore
final class PetPinchTests:XCTestCase {
    func testOriginalPinchCostAndRestPreservation() {
        var state=PetState();state.strength=10;state.feeling=99;state.resting=true
        let engine=PetEngine(state:state)
        XCTAssertEqual(engine.send(.touchPinch),.pinch)
        XCTAssertEqual(engine.state.strength,8);XCTAssertEqual(engine.state.feeling,100)
        XCTAssertTrue(engine.state.resting)
        _ = engine.send(.touchPinch)
        XCTAssertEqual(engine.state.strength,8);XCTAssertEqual(engine.state.feeling,100)
        state.strength=9;state.feeling=50
        let low=PetEngine(state:state);_ = low.send(.touchPinch)
        XCTAssertEqual(low.state.strength,9);XCTAssertEqual(low.state.feeling,50)
    }
    func testLongHoldClaimsOnceAndStillAllowsDragging() {
        var gesture=PetPointerGesture();gesture.begin(x:0,y:0,time:0)
        XCTAssertFalse(gesture.pollHold(time:0.299))
        XCTAssertTrue(gesture.pollHold(time:0.3))
        XCTAssertFalse(gesture.pollHold(time:0.4))
        XCTAssertFalse(gesture.poll(time:0.5,canLift:true))
        XCTAssertEqual(gesture.release(),.none)
        gesture.begin(x:0,y:0,time:1)
        XCTAssertTrue(gesture.pollHold(time:1.4));XCTAssertTrue(gesture.move(x:10,y:0))
        XCTAssertEqual(gesture.release(),.drop)
    }
}
