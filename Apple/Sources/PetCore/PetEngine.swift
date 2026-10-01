import Foundation

public protocol PetClock { var now: TimeInterval { get } }
public struct SystemPetClock: PetClock { public init() {}; public var now: TimeInterval { ProcessInfo.processInfo.systemUptime } }
public protocol PetRandom { mutating func unit() -> Double }
public struct SeededPetRandom: PetRandom {
    private var seed: UInt64
    public init(seed: UInt64) { self.seed = seed }
    public mutating func unit() -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double(seed >> 11) / Double(UInt64(1) << 53)
    }
}
/// Serial simulation owner. Call from a single executor (the app uses MainActor).
public final class PetEngine {
    public private(set) var state: PetState
    private let clock: any PetClock
    private var random: any PetRandom
    private var previous: TimeInterval
    private var remainder = 0.0
    private var activeSeconds = 0.0
    private var lastInteraction = 0.0
    public init(state: PetState = PetState(), clock: any PetClock = SystemPetClock(), random: any PetRandom = SeededPetRandom(seed: UInt64.random(in: 0...UInt64.max))) {
        self.state = state; self.clock = clock; self.random = random; previous = clock.now
    }
    public func recordInteraction() { lastInteraction = activeSeconds }
    public func resetClock() { previous = clock.now; remainder = 0 }
    public func tick() {
        let current = clock.now, delta = current - previous
        previous = current
        // Never catch up a long suspension, sleep, or a backwards clock jump.
        guard delta.isFinite, delta >= 0, delta <= 30 else { remainder = 0; return }
        remainder += delta
        while remainder >= 15 { remainder -= 15; activeSeconds += 15; step() }
    }
    @discardableResult public func send(_ command: PetCommand) -> PetAction {
        lastInteraction = activeSeconds
        switch command {
        case .touchHead, .touchBody:
            if state.strength >= 10 && state.feeling < 100 { state.changeStrength(-2); state.changeFeeling(1) }
            state.resting = false
            return command.isHead ? .head : .body
        case .feed: eat(.meal); return .eat
        case .water: eat(.water); return .drink
        case .toggleRest: state.resting.toggle(); return state.resting ? .sleep : .idle
        }
    }
    private func eat(_ food: PetFood) {
        state.resting = false
        state.experience += food.experience
        state.changeStrength(food.strength / 2); state.storedStrength += food.strength / 2
        state.changeFood(food.food / 2); state.storedFood += food.food / 2
        state.changeDrink(food.drink / 2); state.storedDrink += food.drink / 2
        state.changeFeeling(food.feeling); state.changeHealth(food.health); state.changeAffection(food.affection)
    }
    private func releaseStores() {
        // Deliberately preserves GameSave.StoreTake's discarded <1 remainder.
        let strength = state.storedStrength / 10; state.storedStrength -= strength
        if abs(state.storedStrength) < 1 { state.storedStrength = 0 } else { state.changeStrength(strength) }
        let food = state.storedFood / 10; state.storedFood -= food
        if abs(state.storedFood) < 1 { state.storedFood = 0 } else { state.changeFood(food) }
        let drink = state.storedDrink / 10; state.storedDrink -= drink
        if abs(state.storedDrink) < 1 { state.storedDrink = 0 } else { state.changeDrink(drink) }
    }
    private func step() {
        let t = 0.05
        releaseStores()
        if state.resting {
            state.changeStrength(t * 2); state.changeFood(t)
            if state.food <= 25 { state.changeFood(t) } else if state.food >= 75 { state.changeHealth(t * 2) }
            state.changeDrink(t)
            // Original uses >=25; its subsequent >=75 branch is unreachable.
            if state.drink >= 25 { state.changeDrink(t) } else if state.drink >= 75 { state.changeHealth(t * 2) }
            lastInteraction = activeSeconds
        } else {
            var healthBonus = -2
            if state.food >= 50 {
                state.changeFood(-t); state.changeStrength(t)
                if state.food >= 75 { healthBonus += 1 + Int(random.unit() * 2) }
            } else if state.food <= 25 { state.changeHealth(-random.unit() * t); healthBonus -= 2 }
            if state.drink >= 50 {
                state.changeDrink(-t); state.changeStrength(t)
                if state.drink >= 75 { healthBonus += 1 + Int(random.unit() * 2) }
            } else if state.drink <= 25 { state.changeHealth(-random.unit() * t); healthBonus -= 2 }
            if healthBonus > 0 { state.changeHealth(Double(healthBonus) * t) }
            state.changeFood(-t); state.changeDrink(-t)
            let minutes = (activeSeconds - lastInteraction) / 60
            state.changeFeeling(-(minutes < 1 ? 0 : min(sqrt(minutes) * t / 4, 100.0 / 800)))
        }
        state.experience += t
        if state.feeling >= 75 {
            if state.feeling >= 90 { state.changeAffection(t) }
            state.experience += t * 2; state.changeHealth(t)
        } else if state.feeling <= 25 { state.changeAffection(-t); state.experience -= t }
        // Random.Next(0,1) is always zero in C#; do not add random health loss.
        if state.drink <= 25 { state.experience -= t }
    }
}
private extension PetCommand { var isHead: Bool { if case .touchHead = self { true } else { false } } }
