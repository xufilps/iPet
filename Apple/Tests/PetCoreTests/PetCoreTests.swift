import XCTest
@testable import PetCore

final class FakeClock: PetClock { var now = 0.0 }
struct FixedRandom: PetRandom { var value = 0.0; mutating func unit() -> Double { value } }
final class PetCoreTests: XCTestCase {
    func testOriginalDefaultTick() {
        let clock = FakeClock(); let engine = PetEngine(clock: clock, random: FixedRandom())
        clock.now = 15; engine.tick()
        XCTAssertEqual(engine.state.food, 99.9, accuracy: 1e-8)
        XCTAssertEqual(engine.state.drink, 99.9, accuracy: 1e-8)
        XCTAssertEqual(engine.state.strength, 100)
        XCTAssertEqual(engine.state.experience, 0.05)
        XCTAssertEqual(engine.state.feeling, 60)
    }
    func testThresholdsFromCalMode() {
        var state = PetState(); state.health = 30; XCTAssertEqual(state.mood, .ill)
        state.health = 60; XCTAssertEqual(state.mood, .poor)
        state.health = 61; state.feeling = 90; XCTAssertEqual(state.mood, .happy)
        state.feeling = 45; XCTAssertEqual(state.mood, .poor)
        state.feeling = 80; state.affection = 80; state.health = 18; XCTAssertEqual(state.mood, .ill)
        state.health = 37; XCTAssertEqual(state.mood, .happy)
    }
    func testFeedingAndDeferredRelease() {
        var state = PetState(); state.food = 50; state.strength = 50
        let clock = FakeClock(); let engine = PetEngine(state: state, clock: clock, random: FixedRandom())
        XCTAssertEqual(engine.send(.feed), .eat)
        XCTAssertEqual(engine.state.food, 65); XCTAssertEqual(engine.state.storedFood, 15)
        XCTAssertEqual(engine.state.strength, 55); XCTAssertEqual(engine.state.feeling, 62)
        clock.now = 15; engine.tick()
        XCTAssertEqual(engine.state.food, 66.4, accuracy: 1e-8)
        XCTAssertEqual(engine.state.storedFood, 13.5)
    }
    func testOriginalSetterSideEffects() {
        var state = PetState(); state.food = 1; state.changeFood(-4)
        XCTAssertEqual(state.food, 0); XCTAssertEqual(state.health, 97)
        state.feeling = 1; state.affection = 10; state.changeFeeling(-5)
        XCTAssertEqual(state.health, 95); XCTAssertEqual(state.affection, 8)
        state.affection = 99; state.health = 50; state.changeAffection(5)
        XCTAssertEqual(state.affection, 100); XCTAssertEqual(state.health, 54)
    }
    func testTouchLimitsAndSleepFormula() {
        let clock = FakeClock(); let engine = PetEngine(clock: clock)
        _ = engine.send(.touchHead); XCTAssertEqual(engine.state.strength, 98); XCTAssertEqual(engine.state.feeling, 61)
        _ = engine.send(.toggleRest); clock.now = 15; engine.tick()
        XCTAssertEqual(engine.state.strength, 98.1, accuracy: 1e-8)
        XCTAssertTrue(engine.state.resting); XCTAssertEqual(engine.state.feeling, 61)
        var state = PetState(); state.strength = 9
        let low = PetEngine(state: state); _ = low.send(.touchBody); XCTAssertEqual(low.state.strength, 9)
    }
    func testNoOfflineCatchUpOrClockReversal() {
        let clock = FakeClock(); let engine = PetEngine(clock: clock)
        clock.now = 7200; engine.tick(); XCTAssertEqual(engine.state, PetState())
        clock.now = 10; engine.tick(); XCTAssertEqual(engine.state, PetState())
        clock.now = 25; engine.tick(); XCTAssertEqual(engine.state.food, 99.9, accuracy: 1e-8)
    }
    func testDeterministicTwoHourSimulation() throws {
        let a = FakeClock(), b = FakeClock()
        let first = PetEngine(clock: a, random: SeededPetRandom(seed: 42))
        let second = PetEngine(clock: b, random: SeededPetRandom(seed: 42))
        for index in 1...480 {
            if index % 10 == 0 { _ = first.send(.feed); _ = second.send(.feed) }
            if index % 20 == 0 { _ = first.send(.water); _ = second.send(.water) }
            a.now = Double(index * 15); b.now = a.now; first.tick(); second.tick()
            try first.state.validate()
        }
        XCTAssertEqual(first.state, second.state)
    }
    private func tempStore() throws -> PetSaveStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return PetSaveStore(directory: url)
    }
    func testSaveRoundTripAndBackupRecovery() throws {
        let store = try tempStore(); var state = PetState()
        try store.save(state); state.feeling = 70; try store.save(state)
        XCTAssertEqual(try store.load(), state)
        try Data("broken".utf8).write(to: store.primary)
        XCTAssertEqual(try store.load(), PetState())
        XCTAssertNotNil(store.recoveryMessage)
        let files = try FileManager.default.contentsOfDirectory(atPath: store.directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("pet.corrupt-") })
        try store.save(PetState())
    }
    func testFutureVersionNeverOverwritten() throws {
        let store = try tempStore(); try store.save(PetState())
        let future = Data("{\"version\":99}".utf8); try future.write(to: store.primary)
        XCTAssertThrowsError(try store.load()); XCTAssertThrowsError(try store.save(PetState()))
        XCTAssertEqual(try Data(contentsOf: store.primary), future)
    }
    func testFutureBackupAndLevelDecreaseRemainSafe() throws {
        let store = try tempStore(); try store.save(PetState())
        let future = Data("{\"version\":99}".utf8); try future.write(to: store.backup)
        XCTAssertThrowsError(try store.save(PetState()))
        XCTAssertEqual(try Data(contentsOf: store.backup), future)
        var state = PetState(); state.experience = 100; state.affection = 109; state.feeling = 20; state.drink = 0
        let clock = FakeClock(); let engine = PetEngine(state: state, clock: clock, random: FixedRandom())
        clock.now = 15; engine.tick()
        XCTAssertEqual(engine.state.level, 1)
        XCTAssertGreaterThan(engine.state.affection, engine.state.affectionMax)
        try engine.state.validate()
        let anotherStore = try tempStore(); try anotherStore.save(engine.state)
        XCTAssertEqual(try anotherStore.load(), engine.state)
    }
    func testWriteFailureAndInvalidValues() throws {
        let store = try tempStore(); try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let blocked = store.directory.appendingPathComponent("not-a-folder")
        try Data().write(to: blocked)
        XCTAssertThrowsError(try PetSaveStore(directory: blocked).save(PetState()))
        var state = PetState(); state.health = .nan
        XCTAssertThrowsError(try store.save(state))
    }
}
