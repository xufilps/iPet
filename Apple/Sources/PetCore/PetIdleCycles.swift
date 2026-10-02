// SPDX-License-Identifier: Apache-2.0
public struct PetIdleCycles:Sendable {
    private var length=1 // Next(1) always accepts the first B after A.
    private let limit:Int
    public init(limit:Int) { self.limit=max(0,limit) }
    public mutating func continueAfterLoop(random:inout any PetRandom) -> Bool {
        length=min(1_000_000,length+1)
        let value=random.unit(),unit=value.isFinite ? min(1.0.nextDown,max(0,value)):0
        return Int(unit*Double(length))<=limit
    }
}
