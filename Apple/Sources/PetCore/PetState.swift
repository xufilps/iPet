// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import Foundation

public enum PetMood: String, Codable, Sendable, CaseIterable {
    case happy = "Happy", normal = "Nomal", poor = "PoorCondition", ill = "Ill"
    public var title: String { switch self { case .happy: "开心"; case .normal: "普通"; case .poor: "状态不佳"; case .ill: "生病" } }
}
public struct PetState: Codable, Equatable, Sendable {
    public var name = "萝莉斯"
    public var strength = 100.0
    public var food = 100.0
    public var drink = 100.0
    public var feeling = 60.0
    public var health = 100.0
    public var affection = 0.0
    public var experience = 0.0 {
        didSet {
            guard var next=growth else { return } // Missing only while decoding an older JSON schema.
            do {
                try next.setExperience(experience);growth=next;experience=next.experience
            } catch {
                // Keep the rejected scalar so validation fails, allowing the owner's transaction to roll back.
                // A property assignment inside its own observer does not recursively invoke the observer.
            }
        }
    }
    public var growth:PetDesktopGrowth? = .initial
    public var storedStrength = 0.0
    public var storedFood = 0.0
    public var storedDrink = 0.0
    public var resting = false
    public var money = 100.0
    public var inventory: [String: Int] = [:]
    public var inventoryMetadata: [String:PetInventoryMetadata]?
    public var itemCooldowns: [String: Date] = [:]
    public var catalogVersion = 1
    public var progress:PetProgress?
    public var activity: ActivitySession?
    public var schedule:PetSchedule?
    public var workPackage,studyPackage:PetSignedPackage?
    public init() {}
    /// An explicit opaque/invalid record must never fall back to a same-ID catalog food.
    public func inventoryDefinition(_ id:String,catalog:PetCatalog) -> ItemDefinition? {
        if let owned=inventoryMetadata?[id] { return owned.definition(id:id) }
        return catalog.item(id)
    }
    public func canUseInventory(_ id:String,catalog:PetCatalog) -> Bool {
        guard inventory[id,default:0]>0 else { return false }
        if let owned=inventoryMetadata?[id] {
            return owned.canUse && owned.itemType.utf8.elementsEqual("Food".utf8) && owned.food != nil && (try? owned.validate()) != nil
        }
        return catalog.item(id) != nil
    }
    public var level: Int { growth?.level ?? (Int(sqrt(max(0, min(experience, 1e12))) / 10) + 1) }
    public var strengthMax:Double { growth?.strengthMax ?? 100 }
    public var feelingMax:Double { growth?.feelingMax ?? 100 }
    public var affectionMax: Double { growth?.affectionMax ?? Double(90 + level * 10) }
    public var mood: PetMood {
        if let growth { return growth.mood(health:health,feeling:feeling,affection:affection) }
        let threshold = 60.0 - (feeling >= 80 ? 12 : 0) - (affection >= 80 ? 12 : affection >= 40 ? 6 : 0)
        if health <= threshold { return health <= threshold / 2 ? .ill : .poor }
        let happy = 0.90 - (affection >= 80 ? 0.20 : affection >= 40 ? 0.10 : 0)
        if feeling / 100 >= happy { return .happy }
        return feeling / 100 <= happy / 2 ? .poor : .normal
    }
    public func validate() throws {
        if let metadata=inventoryMetadata {
            // Future parameters must surface before ordinary state errors so their files stay protected.
            if let future=metadata.values.first(where: { $0.version>1 }) { throw PetSaveError.unsupportedInventoryVersion(future.version) }
            guard metadata.count<=10000 else { throw PetSaveError.invalidState }
            for (id,item) in metadata {
                guard !id.isEmpty,id.count<=300,inventory[id] != nil else { throw PetSaveError.invalidState }
                do { try item.validate() } catch { throw PetSaveError.invalidState }
            }
        }
        try growth?.validate()
        if let growth, growth.experience != experience { throw PetSaveError.invalidState }
        try progress?.validate()
        try schedule?.validate(activity:activity)
        guard activity?.scheduleEntryID==nil || schedule?.phase == .activity else { throw PetSaveError.invalidState }
        try workPackage?.validate();try studyPackage?.validate()
        guard workPackage == nil || workPackage?.kind == .work,studyPackage == nil || studyPackage?.kind == .study else { throw PetSaveError.invalidState }
        let retainedStrength=growth?.retainedStrengthCeiling ?? 100,retainedFeeling=growth?.retainedFeelingCeiling ?? 100
        let bounded = [(strength,retainedStrength),(food,retainedStrength),(drink,retainedStrength),(feeling,retainedFeeling),(health,100.0)]
        guard !name.isEmpty, name.count <= 100,
              bounded.allSatisfy({ $0.0.isFinite && (0...$0.1).contains($0.0) }),
              affection.isFinite, (0...(growth == nil ? 1_000_100:1e12)).contains(affection),
              experience.isFinite, abs(experience) <= 1e12,
              [storedStrength, storedFood, storedDrink].allSatisfy({ $0.isFinite && abs($0) <= 10000 }),
              money.isFinite, abs(money) <= 1e12, catalogVersion == 1,
              inventory.allSatisfy({ !$0.key.isEmpty && $0.key.count <= 300 && (0...1000000).contains($0.value) }),
              itemCooldowns.allSatisfy({ !$0.key.isEmpty && $0.key.count <= 300 && $0.value.timeIntervalSince1970.isFinite && abs($0.value.timeIntervalSince1970) <= 1e12 })
        else { throw PetSaveError.invalidState }
        if let a=activity {
            guard (1...400).contains(a.effectiveMultiplier), !a.activityID.isEmpty, a.activityID.count <= 300, a.elapsedSeconds.isFinite, (0...1e12).contains(a.elapsedSeconds), a.earned.isFinite, (0...1e12).contains(a.earned), !resting else { throw PetSaveError.invalidState }
        }
    }
    /// Older iPet documents stored cumulative experience and fixed100 attributes. Preserve their bytes separately.
    mutating func migrateDesktopGrowth() throws {
        guard growth == nil else { throw PetSaveError.invalidDocument }
        try validate()
        let historicalMax=affectionMax
        var next=PetDesktopGrowth.initial;try next.setExperience(experience)
        next=try PetDesktopGrowth(level:next.level,prestige:next.prestige,experience:next.experience,affectionMax:max(next.affectionMax,historicalMax,affection))
        growth=next;experience=next.experience
        try validate()
    }
    mutating func changeStrength(_ delta: Double) { strength = min(strengthMax,max(0,strength+delta)) }
    mutating func changeHealth(_ delta: Double) { health = Self.clamp(health + delta) }
    mutating func changeFood(_ delta: Double) {
        let value = min(strengthMax, food + delta)
        if value <= 0 { changeHealth(value) }
        food = max(0, value)
    }
    mutating func changeDrink(_ delta: Double) {
        let value = min(strengthMax, drink + delta)
        if value <= 0 { changeHealth(value) }
        drink = max(0, value)
    }
    mutating func changeFeeling(_ delta: Double) {
        let value = min(feelingMax, feeling + delta)
        if value <= 0 { changeHealth(value / 2); changeAffection(value / 2) }
        feeling = max(0, value)
    }
    mutating func changeAffection(_ delta: Double) {
        let value = max(0, affection + delta)
        if value > affectionMax { changeHealth(value - affectionMax) }
        affection = min(affectionMax, value)
    }
    static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }
}
public enum PetCommand: Sendable { case touchHead, touchBody, touchPinch, feed, water, toggleRest }
public enum PetAction: String, Codable, Sendable, CaseIterable { case levelUp, say, idle, fidget, stateUp, stateDown, head, body, raised, walkLeft, walkRight, sleep, eat, drink, gift, activity, climb, sideHide, pinch, specialIdle }
public struct PetFood: Sendable {
    public let strength, food, drink, feeling, health, affection, experience: Double
    // Free basics are an Apple v0.1 adaptation, not Windows shop items.
    public static let meal = PetFood(strength: 10, food: 30, drink: 0, feeling: 2, health: 2, affection: 0, experience: 0)
    public static let water = PetFood(strength: 5, food: 0, drink: 30, feeling: 1, health: 1, affection: 0, experience: 0)
}
