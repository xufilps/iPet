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
    public var resourceImagePath:String?
    public var canUse, star, isSingle, visibility:Bool
    public var food:PetLegacyInventoryPreview.Food?

    public init(legacy:PetLegacyInventoryPreview.Item) throws {
        version=1;name=legacy.name;itemType=legacy.itemType;description=legacy.description;data=legacy.data
        price=legacy.price;image=legacy.image;canUse=legacy.canUse;star=legacy.star;isSingle=legacy.isSingle;visibility=legacy.visibility;food=legacy.food
        try validate()
    }
    /// Freeze a current, already loaded catalog item for later inventory use.
    public init(definition:ItemDefinition) throws {
        guard let exp=Int32(exactly:definition.experience),definition.category != .item else { throw ValidationError.invalidParameters }
        version=1;name=definition.name;itemType="Food";description=definition.description;data="";price=definition.price
        image=definition.imagePath;resourceImagePath=definition.imagePath;canUse=true;star=false;isSingle=false;visibility=true
        let category=definition.category.rawValue.prefix(1).uppercased()+definition.category.rawValue.dropFirst()
        food=PetLegacyInventoryPreview.Food(category:category,experience:Int(exp),strength:definition.strength,food:definition.food,drink:definition.drink,feeling:definition.feeling,health:definition.health,affection:definition.affection,graph:definition.graphID)
        try validate()
    }
    public func definition(id:String) -> ItemDefinition? {
        guard (try? validate()) != nil else { return nil }
        let category=food.flatMap { ItemCategory(rawValue:$0.category.lowercased()) } ?? .item
        let defaultGraph=category == .drink ? "drink":category == .gift ? "gift":"eat"
        return ItemDefinition(id:id,name:name,category:category,price:price,strength:food?.strength ?? 0,food:food?.food ?? 0,drink:food?.drink ?? 0,feeling:food?.feeling ?? 0,health:food?.health ?? 0,affection:food?.affection ?? 0,experience:Double(food?.experience ?? 0),imagePath:resourceImagePath,graphID:food?.graph.flatMap { $0.isEmpty ? nil:$0 } ?? defaultGraph,description:description)
    }
    public func validate() throws {
        guard version<=1 else { throw ValidationError.unsupportedVersion(version) }
        guard version==1,!name.isEmpty,name.count<=300,!itemType.isEmpty,itemType.count<=300,
              price.isFinite,abs(price)<=1e12 else { throw ValidationError.invalidParameters }
        let textBytes=description.utf8.count+data.utf8.count+(image?.utf8.count ?? 0)+(food?.graph?.utf8.count ?? 0)
        guard resourceImagePath.map(PetCatalog.safePath) ?? true else { throw ValidationError.invalidParameters }
        guard textBytes<=8*1024*1024 else { throw ValidationError.invalidParameters }
        if itemType.utf8.elementsEqual("Food".utf8) {
            guard let food,["Food","Star","Meal","Snack","Drink","Functional","Drug","Gift"].contains(where: { $0.utf8.elementsEqual(food.category.utf8) }),
                  Int32(exactly:food.experience) != nil,
                  [food.strength,food.food,food.drink,food.feeling,food.health,food.affection].allSatisfy({ $0.isFinite && abs($0)<=1e12 }) else { throw ValidationError.invalidParameters }
        } else if food != nil { throw ValidationError.invalidParameters }
    }
}
