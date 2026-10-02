// SPDX-License-Identifier: Apache-2.0
public struct PetMoodTransition: Equatable, Sendable {
    public let action: PetAction
    public let mood: PetMood
    public init(action: PetAction, mood: PetMood) { self.action=action;self.mood=mood }
    public static func steps(from: PetMood, to: PetMood) -> [Self] {
        let order=PetMood.allCases
        guard let source=order.firstIndex(of:from), let target=order.firstIndex(of:to), source != target else { return [] }
        let direction=source < target ? 1 : -1
        return stride(from:source,to:target,by:direction).map {
            Self(action:direction > 0 ? .stateDown : .stateUp,mood:order[$0])
        }
    }
}
