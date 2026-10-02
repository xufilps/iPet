import XCTest
@testable import PetCore
private struct SpecialRandom:PetRandom { var values:[Double];mutating func unit()->Double { values.isEmpty ? 1.0.nextDown:values.removeFirst() } }
final class PetSpecialIdleTests:XCTestCase {
    func testOriginalOneTwoReturnAndIncreasingCount() {
        var state=PetSpecialIdle(limit:10),random:any PetRandom=SpecialRandom(values:Array(repeating:1.0.nextDown,count:11)+[0])
        for _ in 0..<10 { XCTAssertEqual(state.afterLoop(random:&random),.continueLoop) }
        XCTAssertEqual(state.afterLoop(random:&random),.enterTwo)
        XCTAssertEqual(state.entries,1)
        for _ in 0..<10 { XCTAssertEqual(state.afterLoop(random:&random),.continueLoop) }
        XCTAssertEqual(state.afterLoop(random:&random),.returnOne)
        random=SpecialRandom(values:Array(repeating:1.0.nextDown,count:11)+[0.34])
        for _ in 0..<10 { XCTAssertEqual(state.afterLoop(random:&random),.continueLoop) }
        XCTAssertEqual(state.afterLoop(random:&random),.finish)
    }
    func testBranchSixSelectsSpecialIdle() {
        let clock=FakeClock(),autonomy=PetAutonomy(clock:clock,random:FixedRandom(value:6.0/200))
        clock.now=15
        XCTAssertEqual(autonomy.poll(eligible:true,allowsMovement:false,mood:.normal),.specialIdle)
    }
}
