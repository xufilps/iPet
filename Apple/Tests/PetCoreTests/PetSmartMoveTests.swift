import XCTest
@testable import PetCore
private final class SmartMoveClock:PetClock { var now=0.0 }
final class PetSmartMoveTests:XCTestCase {
    func testOriginalDeadlineBoundaryAndNonRaisedRelease() {
        let clock=SmartMoveClock(),policy=PetSmartMove(clock:clock)
        policy.configure(allowMove:true,enabled:true,interval:30)
        clock.now=29.9;policy.tick();XCTAssertTrue(policy.allowsMovement)
        clock.now=30;policy.tick();XCTAssertFalse(policy.allowsMovement);XCTAssertTrue(policy.isTimedOut)
        policy.interactionEnded(raised:true);XCTAssertFalse(policy.allowsMovement)
        policy.interactionEnded(raised:false);XCTAssertTrue(policy.allowsMovement)
        clock.now=60;policy.tick();XCTAssertFalse(policy.allowsMovement)
    }
    func testDisabledFeatureAndMoveSwitchTakePrecedence() {
        let clock=SmartMoveClock(),policy=PetSmartMove(clock:clock)
        policy.configure(allowMove:false,enabled:true,interval:30)
        policy.interactionEnded(raised:false);XCTAssertFalse(policy.allowsMovement)
        policy.configure(allowMove:true,enabled:false,interval:30)
        for time in stride(from:30.0,through:3000,by:30) { clock.now=time;policy.tick() }
        XCTAssertTrue(policy.allowsMovement);XCTAssertFalse(policy.isTimedOut)
        policy.configure(allowMove:true,enabled:true,interval:30)
        clock.now=3030;policy.tick();XCTAssertFalse(policy.allowsMovement)
    }
    func testSleepPreservesRemainingTimeAndInvalidClockDoesNotExpire() {
        let clock=SmartMoveClock(),policy=PetSmartMove(clock:clock)
        policy.configure(allowMove:true,enabled:true,interval:30)
        clock.now=10;policy.pause()
        clock.now=1010;policy.tick();XCTAssertFalse(policy.allowsMovement)
        policy.resume();clock.now=1029.9;policy.tick();XCTAssertTrue(policy.allowsMovement)
        clock.now=1030;policy.tick();XCTAssertFalse(policy.allowsMovement)
        policy.configure(allowMove:true,enabled:true,interval:30)
        for time in [Double.nan,Double.infinity,1000,2000] { clock.now=time;policy.tick() }
        XCTAssertTrue(policy.allowsMovement)
        clock.now=2030;policy.tick();XCTAssertFalse(policy.allowsMovement)
    }
    func testOriginalIntervalChoicesAndInvalidPreferenceFallback() {
        let policy=PetSmartMove()
        XCTAssertEqual(PetSmartMove.intervals,[30,60,120,300,600,1200,1800,2400,3000,3600])
        policy.configure(allowMove:true,enabled:true,interval:-1)
        XCTAssertEqual(policy.interval,1200)
        policy.configure(allowMove:true,enabled:true,interval:2400)
        XCTAssertEqual(policy.interval,2400)
    }
}
