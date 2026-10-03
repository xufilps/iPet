// Source: VPet 1a06c598 Item/Food. Quantity is owned exclusively by PetState.inventory.
// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Persistable parameters only. Image/Graph are opaque upstream identifiers, never filesystem authority.
/// The owner must call validate after decoding and before publishing or saving this value.
public struct PetInventoryMetadata: Codable, Equatable, Sendable {
    public enum ValidationError: Error, Equatable { case unsupportedVersion(Int), invalidParameters }
    public let version:Int
    public var name, itemType, description, data:String
    public var price:Double
    public var image:String?
    public var canUse, star, isSingle, visibility:Bool
    public var food:PetLegacyInventoryPreview.Food?

    public init(legacy:PetLegacyInventoryPreview.Item) throws {
        version=1;name=legacy.name;itemType=legacy.itemType;description=legacy.description;data=legacy.data
        price=legacy.price;image=legacy.image;canUse=legacy.canUse;star=legacy.star;isSingle=legacy.isSingle;visibility=legacy.visibility;food=legacy.food
        try validate()
    }
    public func validate() throws {
        guard version<=1 else { throw ValidationError.unsupportedVersion(version) }
        guard version==1,!name.isEmpty,name.count<=300,!itemType.isEmpty,itemType.count<=300,
              price.isFinite,abs(price)<=1e12 else { throw ValidationError.invalidParameters }
        let textBytes=description.utf8.count+data.utf8.count+(image?.utf8.count ?? 0)+(food?.graph?.utf8.count ?? 0)
        guard textBytes<=8*1024*1024 else { throw ValidationError.invalidParameters }
        if itemType.utf8.elementsEqual("Food".utf8) {
            guard let food,["Food","Star","Meal","Snack","Drink","Functional","Drug","Gift"].contains(where: { $0.utf8.elementsEqual(food.category.utf8) }),
                  Int32(exactly:food.experience) != nil,
                  [food.strength,food.food,food.drink,food.feeling,food.health,food.affection].allSatisfy({ $0.isFinite && abs($0)<=1e12 }) else { throw ValidationError.invalidParameters }
        } else if food != nil { throw ValidationError.invalidParameters }
    }
}
