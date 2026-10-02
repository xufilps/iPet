import XCTest
@testable import PetCore
private struct MoveFixedRandom:PetRandom { let value:Double;mutating func unit()->Double { value } }
final class PetMoveCycleTests:XCTestCase {
    func testEarliestExitFollowsOriginalPostIncrementCounter() {
        let cycles=PetMoveCycles(random:MoveFixedRandom(value:1))
        cycles.begin(distance:5)
        for _ in 1...5 { XCTAssertTrue(cycles.continueAfterLoop()) }
        XCTAssertFalse(cycles.continueAfterLoop())
        cycles.begin(distance:7)
        for _ in 1...7 { XCTAssertTrue(cycles.continueAfterLoop()) }
        XCTAssertFalse(cycles.continueAfterLoop())
    }
    func testCompatibilityProbabilityBoundaryAndInvalidRandom() {
        XCTAssertTrue(PetMoveCycles(random:MoveFixedRandom(value:0.399)).triesCompatibility())
        XCTAssertFalse(PetMoveCycles(random:MoveFixedRandom(value:0.4)).triesCompatibility())
        let cycles=PetMoveCycles(random:MoveFixedRandom(value:.nan));cycles.begin(distance:8)
        XCTAssertTrue(cycles.continueAfterLoop());XCTAssertTrue(cycles.triesCompatibility())
    }
}
