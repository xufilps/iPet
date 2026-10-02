// SPDX-License-Identifier: Apache-2.0
public struct PetSpecialIdle:Sendable {
    public enum Decision:Equatable,Sendable { case continueLoop,enterTwo,returnOne,finish }
    public private(set) var entries=0
    private var inTwo=false
    private var cycles:PetIdleCycles
    private let limit:Int
    public init(limit:Int) { self.limit=limit;cycles=PetIdleCycles(limit:limit) }
    public mutating func afterLoop(random:inout any PetRandom) -> Decision {
        if cycles.continueAfterLoop(random:&random) { return .continueLoop }
        cycles=PetIdleCycles(limit:limit)
        if inTwo { inTwo=false;return .returnOne }
        let value=random.unit(),unit=value.isFinite ? min(1.0.nextDown,max(0,value)):0
        if Int(unit*Double(2+entries)) == 0 {
            entries=min(1_000_000,entries+1);inTwo=true;return .enterTwo
        }
        return .finish
    }
}
