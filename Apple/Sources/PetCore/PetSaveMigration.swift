// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetSaveMigration {
    private struct LegacyDocument: Decodable {
        let version: Int
        let state: LegacyState
    }
    private struct LegacyState: Decodable {
        let name: String
        let strength, food, drink, feeling, health, affection, experience, storedStrength, storedFood, storedDrink: Double
        let resting: Bool
    }
    public static func decodeLegacy(_ data: Data) throws -> PetState {
        let document=try JSONDecoder().decode(LegacyDocument.self,from:data)
        guard document.version == 1 else { throw PetSaveError.invalidDocument }
        let old=document.state
        guard [old.storedStrength,old.storedFood,old.storedDrink].allSatisfy({ $0 >= 0 }) else { throw PetSaveError.invalidState }
        var state=PetState();state.growth=nil;state.money=1000;state.name=old.name;state.strength=old.strength;state.food=old.food;state.drink=old.drink;state.feeling=old.feeling;state.health=old.health;state.affection=old.affection;state.experience=old.experience;state.storedStrength=old.storedStrength;state.storedFood=old.storedFood;state.storedDrink=old.storedDrink;state.resting=old.resting
        try state.migrateDesktopGrowth();return state
    }
}
