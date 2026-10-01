// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetItemRules {
    public static func multiplier(category: ItemCategory, expiry: Date?, now: Date) -> Double {
        let hours=max(0,(expiry?.timeIntervalSince(now) ?? 0)/3600)
        return max(0.5,1-hours*hours*(category == .gift ? 0.01 : 0.02))
    }
    static func apply(_ item: ItemDefinition, to state: inout PetState, now: Date) {
        let hours=max(0,(state.itemCooldowns[item.id]?.timeIntervalSince(now) ?? 0)/3600)
        let buff=multiplier(category:item.category,expiry:state.itemCooldowns[item.id],now:now)
        state.experience += item.experience*buff
        state.changeStrength(item.strength/2*buff);state.storedStrength += item.strength/2*buff
        state.changeFood(item.food/2*buff);state.storedFood += item.food/2*buff
        state.changeDrink(item.drink/2*buff);state.storedDrink += item.drink/2*buff
        state.changeFeeling(item.feeling*buff);state.changeHealth(item.health*buff);state.changeAffection(item.affection*buff)
        let added=max(0.5,min(4,2-(item.affection+item.feeling/2)/5))
        state.itemCooldowns[item.id]=now.addingTimeInterval((hours+added)*3600)
    }
}
