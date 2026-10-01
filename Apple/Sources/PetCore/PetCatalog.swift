// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum ActivityKind: String, Codable, Sendable, CaseIterable { case work, study, play
    public var title: String { switch self { case .work: "工作"; case .study: "学习"; case .play: "娱乐" } }
}
public struct ActivityDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id, name, graphID: String
    public var kind: ActivityKind
    public var durationSeconds: Double
    public var levelLimit: Int
    public var moneyBase, strengthFood, strengthDrink, feeling, finishBonus: Double
    public init(id: String, name: String, graphID: String, kind: ActivityKind, durationSeconds: Double, levelLimit: Int = 0, moneyBase: Double, strengthFood: Double, strengthDrink: Double, feeling: Double, finishBonus: Double) {
        self.id=id; self.name=name; self.graphID=graphID; self.kind=kind; self.durationSeconds=durationSeconds; self.levelLimit=levelLimit; self.moneyBase=moneyBase; self.strengthFood=strengthFood; self.strengthDrink=strengthDrink; self.feeling=feeling; self.finishBonus=finishBonus
    }
}
public enum ItemCategory: String, Codable, Sendable, CaseIterable { case food, meal, snack, drink, functional, drug, gift
    public var title: String { switch self { case .food: "食物"; case .meal: "正餐"; case .snack: "零食"; case .drink: "饮料"; case .functional: "功能性"; case .drug: "药品"; case .gift: "礼品" } }
}
public struct ItemDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id, name, description, graphID: String
    public var category: ItemCategory
    public var imagePath: String?
    public var price, strength, food, drink, feeling, health, affection, experience: Double
    public init(id: String, name: String, category: ItemCategory = .food, price: Double, strength: Double = 0, food: Double = 0, drink: Double = 0, feeling: Double = 0, health: Double = 0, affection: Double = 0, experience: Double = 0, imagePath: String? = nil, graphID: String = "eat", description: String = "") {
        self.id=id; self.name=name; self.category=category; self.price=price; self.strength=strength; self.food=food; self.drink=drink; self.feeling=feeling; self.health=health; self.affection=affection; self.experience=experience; self.imagePath=imagePath; self.graphID=graphID; self.description=description
    }
    public var effectDescription: String {
        zip(["体力","饱腹","饮水","心情","健康","好感","经验"],[strength,food,drink,feeling,health,affection,experience]).filter { $0.1 != 0 }.map { "\($0.0) \($0.1 > 0 ? "+" : "")\($0.1.formatted(.number.precision(.fractionLength(0...2))))" }.joined(separator: " · ")
    }
}
public struct PetCatalog: Codable, Equatable, Sendable {
    public var version: Int
    public var activities: [ActivityDefinition]
    public var items: [ItemDefinition]
    public init(activities: [ActivityDefinition] = [], items: [ItemDefinition] = [], version: Int = 1) { self.activities=activities; self.items=items; self.version=version }
    public static func load(from url: URL) throws -> Self { let value=try JSONDecoder().decode(Self.self,from: Data(contentsOf: url)); try value.validate(); return value }
    public func activity(_ id: String) -> ActivityDefinition? { activities.first { $0.id == id } }
    public func item(_ id: String) -> ItemDefinition? { items.first { $0.id == id } }
    public static func safePath(_ path: String) -> Bool { !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.split(separator: "/").contains("..") && !path.contains(":") }
    public func validate() throws {
        guard version == 1, Set(activities.map(\.id)).count == activities.count, Set(items.map(\.id)).count == items.count else { throw PetSaveError.invalidDocument }
        for a in activities {
            guard !a.id.isEmpty, !a.name.isEmpty, !a.graphID.isEmpty, a.levelLimit >= 0, a.durationSeconds > 0, [a.durationSeconds,a.moneyBase,a.strengthFood,a.strengthDrink,a.feeling,a.finishBonus].allSatisfy({ $0.isFinite && abs($0) <= 1e12 }), (0...2).contains(a.finishBonus) else { throw PetSaveError.invalidDocument }
        }
        for i in items {
            guard !i.id.isEmpty, !i.name.isEmpty, !i.graphID.isEmpty, i.price >= 0, [i.price,i.strength,i.food,i.drink,i.feeling,i.health,i.affection,i.experience].allSatisfy({ $0.isFinite && abs($0) <= 1e12 }), i.imagePath.map(Self.safePath) ?? true else { throw PetSaveError.invalidDocument }
        }
    }
}
