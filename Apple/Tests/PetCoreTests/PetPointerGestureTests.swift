import XCTest
@testable import PetCore
final class PetPointerGestureTests: XCTestCase {
    func testEachTouchSettlesOriginalPropertiesOnce() {
        let engine=PetEngine()
        _=engine.send(.touchHead);_=engine.send(.touchHead)
        XCTAssertEqual(engine.state.strength,96);XCTAssertEqual(engine.state.feeling,62)
    }
    func testTapAndLongPressAreMutuallyExclusive() {
        var gesture=PetPointerGesture()
        gesture.begin(x:0,y:0,time:10)
        XCTAssertFalse(gesture.poll(time:10.299,canLift:true))
        XCTAssertEqual(gesture.release(),.tap)
        gesture.begin(x:0,y:0,time:20)
        XCTAssertTrue(gesture.poll(time:20.301,canLift:true))
        XCTAssertFalse(gesture.poll(time:21,canLift:true))
        XCTAssertEqual(gesture.release(),.drop)
        XCTAssertEqual(gesture.release(),.none)
    }
    func testMovementWinsWithoutDuplicateLiftAndCancellationDropsPendingTap() {
        var gesture=PetPointerGesture()
        gesture.begin(x:0,y:0,time:0)
        XCTAssertFalse(gesture.move(x:4,y:0))
        XCTAssertTrue(gesture.move(x:4.01,y:0))
        XCTAssertFalse(gesture.poll(time:1,canLift:true))
        XCTAssertFalse(gesture.move(x:10,y:10))
        XCTAssertEqual(gesture.release(),.drop)
        gesture.begin(x:0,y:0,time:0)
        gesture.cancel()
        XCTAssertFalse(gesture.poll(time:2,canLift:true));XCTAssertEqual(gesture.release(),.none)
    }
    func testOutOfRegionHoldDoesNotTurnIntoPettingButCanStillDrag() {
        var gesture=PetPointerGesture()
        gesture.begin(x:0,y:0,time:0)
        XCTAssertFalse(gesture.poll(time:0.301,canLift:false))
        XCTAssertEqual(gesture.release(),.none)
        gesture.begin(x:0,y:0,time:0)
        XCTAssertFalse(gesture.poll(time:0.301,canLift:false))
        XCTAssertTrue(gesture.move(x:10,y:0));XCTAssertEqual(gesture.release(),.drop)
    }
}
