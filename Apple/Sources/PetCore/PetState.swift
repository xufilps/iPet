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
    public var experience = 0.0
    public var storedStrength = 0.0
    public var storedFood = 0.0
    public var storedDrink = 0.0
    public var resting = false
    public var money = 1000.0
    public var inventory: [String: Int] = [:]
    public var itemCooldowns: [String: Date] = [:]
    public var catalogVersion = 1
    public var progress:PetProgress?
    public var activity: ActivitySession?
    public var workPackage,studyPackage:PetSignedPackage?
    public init() {}
    public var level: Int { Int(sqrt(max(0, min(experience, 1e12))) / 10) + 1 }
    public var affectionMax: Double { Double(90 + level * 10) }
    public var mood: PetMood {
        let threshold = 60.0 - (feeling >= 80 ? 12 : 0) - (affection >= 80 ? 12 : affection >= 40 ? 6 : 0)
        if health <= threshold { return health <= threshold / 2 ? .ill : .poor }
        let happy = 0.90 - (affection >= 80 ? 0.20 : affection >= 40 ? 0.10 : 0)
        if feeling / 100 >= happy { return .happy }
        return feeling / 100 <= happy / 2 ? .poor : .normal
    }
    public func validate() throws {
        try progress?.validate()
        try workPackage?.validate();try studyPackage?.validate()
        guard workPackage == nil || workPackage?.kind == .work,studyPackage == nil || studyPackage?.kind == .study else { throw PetSaveError.invalidState }
        let bounded = [strength, food, drink, feeling, health]
        guard !name.isEmpty, name.count <= 100,
              bounded.allSatisfy({ $0.isFinite && (0...100).contains($0) }),
              affection.isFinite, (0...1_000_100).contains(affection),
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
    mutating func changeStrength(_ delta: Double) { strength = Self.clamp(strength + delta) }
    mutating func changeHealth(_ delta: Double) { health = Self.clamp(health + delta) }
    mutating func changeFood(_ delta: Double) {
        let value = min(100, food + delta)
        if value <= 0 { changeHealth(value) }
        food = max(0, value)
    }
    mutating func changeDrink(_ delta: Double) {
        let value = min(100, drink + delta)
        if value <= 0 { changeHealth(value) }
        drink = max(0, value)
    }
    mutating func changeFeeling(_ delta: Double) {
        let value = min(100, feeling + delta)
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
public enum PetAction: String, Codable, Sendable, CaseIterable { case idle, fidget, stateUp, stateDown, head, body, raised, walkLeft, walkRight, sleep, eat, drink, gift, activity, climb, sideHide, pinch, specialIdle }
public struct PetFood: Sendable {
    public let strength, food, drink, feeling, health, affection, experience: Double
    // Free basics are an Apple v0.1 adaptation, not Windows shop items.
    public static let meal = PetFood(strength: 10, food: 30, drink: 0, feeling: 2, health: 2, affection: 0, experience: 0)
    public static let water = PetFood(strength: 5, food: 0, drink: 30, feeling: 1, health: 1, affection: 0, experience: 0)
}
