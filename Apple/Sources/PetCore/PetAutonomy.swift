// SPDX-License-Identifier: Apache-2.0
import Foundation

public enum PetAutonomousBehavior: Equatable, Sendable {
    case walkLeft, walkRight, fidget, doze, specialIdle
}
/// Visual-only selection. Does not change the pet's economy, resting state or save.
public final class PetAutonomy {
    private let clock: any PetClock
    private var random: any PetRandom
    private var previous: TimeInterval
    private var nextSample: TimeInterval
    public private(set) var idleCycles = 0
    public private(set) var fidgetGraphID = "boring"
    public init(clock: any PetClock = SystemPetClock(), random: any PetRandom = SeededPetRandom(seed: UInt64.random(in: 0...UInt64.max))) {
        self.clock=clock;self.random=random;previous=clock.now;nextSample=previous+15
    }
    public static func canStart(state: PetState, action: PetAction, visible: Bool, interacting: Bool, finishing: Bool) -> Bool {
        visible && !interacting && !finishing && action == .idle && !state.resting && state.activity == nil
    }
    public func reset() { previous=clock.now;nextSample=previous+15;idleCycles=0 }
    public func recordIdleCycle() { idleCycles=min(1_000_000,idleCycles+1) }
    private func unit() -> Double {
        let value=random.unit()
        return value.isFinite ? min(1.0.nextDown,max(0,value)) : 0
    }
    public func poll(eligible: Bool, allowsMovement: Bool, mood: PetMood) -> PetAutonomousBehavior? {
        let now=clock.now, delta=now-previous
        guard now.isFinite, delta.isFinite, delta >= 0, delta <= 30 else { reset();return nil }
        previous=now
        guard now >= nextSample else { return nil }
        nextSample=now+15
        guard eligible else { return nil }
        let roll=Int(unit()*Double(max(20,200-idleCycles)))
        switch roll {
        case 0...2:
            guard allowsMovement, mood != .ill else { return nil }
            return unit() < 0.5 ? .walkLeft : .walkRight
        case 3...5:
            idleCycles=0;fidgetGraphID=unit() < 0.5 ? "boring" : "squat"
            return .fidget
        case 6: idleCycles=0;return .specialIdle
        case 7: idleCycles=0;return .doze
        default: return nil // Extension interaction pools remain a separate migration task.
        }
    }
}
