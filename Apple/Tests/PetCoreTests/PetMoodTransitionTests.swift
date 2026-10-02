import XCTest
@testable import PetCore
final class PetMoodTransitionTests: XCTestCase {
    func testOriginalAdjacentStateOrderAndSourceMood() {
        XCTAssertEqual(PetMoodTransition.steps(from:.happy,to:.ill),[
            .init(action:.stateDown,mood:.happy),.init(action:.stateDown,mood:.normal),.init(action:.stateDown,mood:.poor)])
        XCTAssertEqual(PetMoodTransition.steps(from:.ill,to:.happy),[
            .init(action:.stateUp,mood:.ill),.init(action:.stateUp,mood:.poor),.init(action:.stateUp,mood:.normal)])
        XCTAssertTrue(PetMoodTransition.steps(from:.normal,to:.normal).isEmpty)
    }
}
