// SPDX-License-Identifier: Apache-2.0
import Foundation

/// GameSave_VPet desktop progression, distinct from the older Core/GameSave cumulative model.
/// PetState uses this model; persistence upgrades older cumulative saves before adoption.
public struct PetDesktopGrowth:Codable,Equatable,Sendable {
    public static let initial=Self(initial:())
    private init(initial:Void) { level=1;prestige=0;experience=0;affectionMax=100 }
    public private(set) var level:Int
    public private(set) var prestige:Int
    public private(set) var experience:Double
    public private(set) var affectionMax:Double
    public init(level:Int=1,prestige:Int=0,experience:Double=0,affectionMax:Double=100) throws {
        self.level=level;self.prestige=prestige;self.experience=experience;self.affectionMax=affectionMax
        try validate()
    }
    public var nextLevelExperience:Double { Double(200*level-100) }
    public var strengthMax:Double { 100+Double(Int(pow(Double(level)*Double(1+prestige),0.75)*4)) }
    public var feelingMax:Double { 100+Double(Int(pow(Double(level)*Double(1+prestige),0.75)*2)) }
    /// Prestige changes level without touching raw attributes. A previous terminal cap can remain until mutation.
    public var retainedStrengthCeiling:Double { retainedCeiling(factor:4,current:strengthMax) }
    public var retainedFeelingCeiling:Double { retainedCeiling(factor:2,current:feelingMax) }
    private func retainedCeiling(factor:Double,current:Double) -> Double {
        guard prestige>0 else { return current }
        let previousTerminal=1000+100*(prestige-1)
        return max(current,100+Double(Int(pow(Double(previousTerminal)*Double(prestige),0.75)*factor)))
    }
    public func validate() throws {
        guard (0...10000).contains(prestige),(1...(1000+100*prestige)).contains(level),
              experience.isFinite,abs(experience)<=1e12,experience<nextLevelExperience,
              affectionMax.isFinite,(0...1e12).contains(affectionMax) else { throw PetSaveError.invalidState }
    }
    private enum CodingKeys:String,CodingKey { case level,prestige,experience,affectionMax }
    public init(from decoder:any Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(level:c.decode(Int.self,forKey:.level),prestige:c.decode(Int.self,forKey:.prestige),experience:c.decode(Double.self,forKey:.experience),affectionMax:c.decode(Double.self,forKey:.affectionMax))
    }
    /// Absolute remaining experience setter, as in the C# property. Negative values never demote.
    @discardableResult public mutating func setExperience(_ value:Double) throws -> PetDesktopLevelChange? {
        guard value.isFinite,abs(value)<=1e12 else { throw PetSaveError.invalidState }
        var next=self;next.experience=value
        var count=0
        while next.experience>=next.nextLevelExperience {
            let maximum=1000+100*next.prestige,nextCount=maximum-next.level+1
            // Sum of n thresholds starting at level L: 100*n*(2*L+n-2).
            func cost(_ n:Int) -> Double { 100*Double(n)*(2*Double(next.level)+Double(n)-2) }
            var low=1,high=nextCount
            while low<high {
                let middle=low+(high-low+1)/2
                if cost(middle)<=next.experience { low=middle } else { high=middle-1 }
            }
            next.experience-=cost(low);next.level+=low;next.affectionMax+=Double(low)*10;count+=low
            if next.level>maximum {
                guard next.prestige<10000 else { throw PetSaveError.invalidState }
                next.prestige+=1;next.level=100*next.prestige
            }
        }
        try next.validate()
        let change=count>0 ? PetDesktopLevelChange(beforeLevel:level,afterLevel:next.level,beforePrestige:prestige,afterPrestige:next.prestige,levelUps:count):nil
        self=next;return change
    }
    @discardableResult public mutating func addExperience(_ amount:Double) throws -> PetDesktopLevelChange? {
        guard amount.isFinite else { throw PetSaveError.invalidState }
        return try setExperience(experience+amount)
    }
    /// Preserve the desktop source's ratio >= 80 quirk; do not silently change it to 0.8.
    public func mood(health:Double,feeling:Double,affection:Double) -> PetMood {
        let threshold=60.0-(feeling/feelingMax>=80 ? 12:0)-(affection>=80 ? 12:affection>=40 ? 6:0)
        if health<=threshold { return health<=threshold/2 ? .ill:.poor }
        let happy=0.90-(affection>=80 ? 0.20:affection>=40 ? 0.10:0)
        let ratio=feeling/feelingMax
        return ratio>=happy ? .happy:ratio<=happy/2 ? .poor:.normal
    }
}
public struct PetDesktopLevelChange:Equatable,Sendable {
    public let beforeLevel,afterLevel,beforePrestige,afterPrestige,levelUps:Int
    public var didPrestige:Bool { afterPrestige>beforePrestige }
}
