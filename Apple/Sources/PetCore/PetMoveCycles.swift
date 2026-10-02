// SPDX-License-Identifier: Apache-2.0
public final class PetMoveCycles {
    private var random:any PetRandom
    private var length=1,distance=7
    public init(random:any PetRandom=SeededPetRandom(seed:UInt64.random(in:0...UInt64.max))) { self.random=random }
    public func begin(distance:Int) { self.distance=max(1,distance);length=1 }
    private func next(_ upper:Int) -> Int {
        let value=random.unit(),unit=value.isFinite ? min(1.0.nextDown,max(0,value)) : 0
        return Int(unit*Double(upper))
    }
    /// First B loop was already accepted by the original Next(0) check.
    public func continueAfterLoop() -> Bool {
        let result=next(length)<distance;length=min(1_000_000,length+1);return result
    }
    public func triesCompatibility() -> Bool { next(5)<=1 }
}
