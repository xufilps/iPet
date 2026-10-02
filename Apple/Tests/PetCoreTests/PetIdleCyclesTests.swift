import XCTest
@testable import PetCore
private struct IdleRandom:PetRandom { let value:Double;mutating func unit()->Double { value } }
final class PetIdleCyclesTests:XCTestCase {
    func testOriginalGreaterThanDurationBoundary() {
        var cycles=PetIdleCycles(limit:20),random:any PetRandom=IdleRandom(value:1.0.nextDown)
        for _ in 2...21 { XCTAssertTrue(cycles.continueAfterLoop(random:&random)) }
        XCTAssertFalse(cycles.continueAfterLoop(random:&random))
    }
    func testFixedAndInvalidRandomRemainRepeatable() {
        func run()->[Bool] {
            var cycles=PetIdleCycles(limit:10),random:any PetRandom=SeededPetRandom(seed:37)
            return (0..<40).map { _ in cycles.continueAfterLoop(random:&random) }
        }
        XCTAssertEqual(run(),run());XCTAssertTrue(run().contains(false))
        var cycles=PetIdleCycles(limit:0),random:any PetRandom=IdleRandom(value:.nan)
        XCTAssertTrue(cycles.continueAfterLoop(random:&random))
    }
}
