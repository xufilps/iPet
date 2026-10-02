// SPDX-License-Identifier: Apache-2.0
import Foundation
public extension ActivityDefinition {
    /// winWorkMenu caps the level used for the selector at 4000.
    func maximumMultiplier(level:Int) -> Int {
        guard levelLimit>=0,levelLimit<=Int.max-10 else { return 1 }
        return max(1,min(4000,max(0,level))/(levelLimit+10))
    }
    /// Mirrors ExtensionFunction.Double: 1 returns the original; >1 always fixes overload.
    func multiplied(by multiplier:Int) -> ActivityDefinition? {
        guard (1...400).contains(multiplier),levelLimit<=Int.max/400-10 else { return nil }
        do { try PetCatalog(activities:[self]).validate() } catch { return nil }
        if multiplier == 1 { return self }
        var work=self
        let scale=0.5+0.4*Double(multiplier)
        work.strengthFood*=scale;work.strengthDrink*=scale;work.feeling*=scale
        work.levelLimit=(levelLimit+10)*multiplier
        work.fixMultiplierOverload()
        do { try PetCatalog(activities:[work]).validate() } catch { return nil }
        return work
    }
    private static func signedPower(_ value:Double,_ exponent:Double) -> Double {
        value == 0 ? 0:pow(abs(value),exponent)*(value<0 ? -1:1)
    }
    private var spend:Double {
        (Self.signedPower(strengthFood,1.5)/3+Self.signedPower(strengthDrink,1.5)/4+Self.signedPower(feeling,1.5)/4 +
         Double(levelLimit)/10+Self.signedPower(strengthFood+strengthDrink+feeling,1.5)/10)*3
    }
    private var gainCap:Double { (1.1*Double(levelLimit)+10)*(kind == .work ? 1:10) }
    private var overloaded:Bool {
        let value=abs(moneyBase)*(1+finishBonus/2)+1
        let gain=Self.signedPower(kind == .work ? value:value/10,1.25)
        let ratio=gain/spend // Preserve original IEEE infinity/NaN comparisons.
        return ratio<0 || abs(moneyBase)>gainCap || ratio>1.4
    }
    private mutating func fixMultiplierOverload() {
        levelLimit=max(0,levelLimit);finishBonus=min(2,max(0,finishBonus));durationSeconds=max(600,durationSeconds)
        if kind == .play && feeling>0 { feeling = -feeling }
        let cost=spend
        if cost>0 {
            let base=2*(1.15*pow(cost,0.8)-1)/(2+finishBonus)*(kind == .work ? 1:10)
            moneyBase=min((base*10).rounded(.toNearestOrEven)/10,gainCap)
        }
        if overloaded {
            switch kind {
            case .work: moneyBase=8;strengthFood=3.5;strengthDrink=2.5;feeling=1;finishBonus=0.1
            case .study: moneyBase=80;strengthFood=2;strengthDrink=2;feeling=3;finishBonus=0.2
            case .play: moneyBase=18;strengthFood=1;strengthDrink=1.5;feeling = -1;finishBonus=0.2
            }
            levelLimit=0
        }
    }
}
public extension PetCatalog {
    func activity(for session:ActivitySession) -> ActivityDefinition? {
        activity(session.activityID)?.multiplied(by:session.effectiveMultiplier)
    }
}
