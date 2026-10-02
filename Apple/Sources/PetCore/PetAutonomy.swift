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
    public private(set) var interactionCycle:Int
    public private(set) var fidgetGraphID = "boring"
    public init(clock: any PetClock = SystemPetClock(), random: any PetRandom = SeededPetRandom(seed: UInt64.random(in: 0...UInt64.max)), interactionCycle:Int=200) {
        self.clock=clock;self.random=random;previous=clock.now;nextSample=previous+15
        self.interactionCycle=min(1000,max(30,interactionCycle))
    }
    public static func canStart(state: PetState, action: PetAction, visible: Bool, interacting: Bool, finishing: Bool) -> Bool {
        guard visible,!interacting,!finishing,!state.resting else { return false }
        if state.activity == nil { return action == .idle }
        return action == .activity && state.activity?.isPaused == false
    }
    public func setInteractionCycle(_ value:Int) { interactionCycle=min(1000,max(30,value)) }
    public func reset() { previous=clock.now;nextSample=previous+15;idleCycles=0 }
    public func recordIdleCycle() { idleCycles=min(1_000_000,idleCycles+1) }
    private func unit() -> Double {
        let value=random.unit()
        return value.isFinite ? min(1.0.nextDown,max(0,value)) : 0
    }
    public func poll(eligible: Bool, allowsMovement: Bool, mood: PetMood,working:Bool=false) -> PetAutonomousBehavior? {
        let now=clock.now, delta=now-previous
        guard now.isFinite, delta.isFinite, delta >= 0, delta <= 30 else { reset();return nil }
        previous=now
        guard now >= nextSample else { return nil }
        nextSample=now+15
        guard eligible else { return nil }
        let range=max(20,interactionCycle-idleCycles)
        let roll=Int(unit()*Double(working ? 2*range+20:range))
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
