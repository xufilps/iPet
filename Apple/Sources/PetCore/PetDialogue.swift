// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct PetDialogueEffects: Codable, Equatable, Sendable {
    public var money, strength, food, drink, feeling, health, affection, experience:Double
    public init(money:Double=0,strength:Double=0,food:Double=0,drink:Double=0,feeling:Double=0,health:Double=0,affection:Double=0,experience:Double=0) {
        self.money=money;self.strength=strength;self.food=food;self.drink=drink;self.feeling=feeling;self.health=health;self.affection=affection;self.experience=experience
    }
    public var isValid:Bool { [money,strength,food,drink,feeling,health,affection,experience].allSatisfy { $0.isFinite && abs($0)<=1e6 } }
    var petFood:PetFood { PetFood(strength:strength,food:food,drink:drink,feeling:feeling,health:health,affection:affection,experience:experience) }
}
public struct PetTextEntry:Codable,Sendable {
    public var id, kind, text:String
    public var tags:[String]
    public var mode,dayTime:Int
    public var workState:String
    public var working:String?
    public var bounds:[String:Double]
    public var effects:PetDialogueEffects
    public var lowMode,severity:String?
    public var like:Int
    public func matchesClick(state:PetState,activityName:String?,hour:Int) -> Bool {
        let hourMask=hour<6 ? 8 : hour<12 ? 1 : hour<18 ? 2 : 4
        let moodMask=1 << (PetMood.allCases.firstIndex(of:state.mood) ?? 1)
        guard kind=="click",(0..<24).contains(hour),dayTime & hourMask != 0,mode & moodMask != 0 else { return false }
        let active=state.activity != nil && state.activity?.isPaused == false
        if let working, !working.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            guard active, activityName==working else { return false }
        } else {
            let current=state.resting ? "Sleep" : active ? "Work" : "Nomal"
            guard current==workState else { return false }
        }
        let values=["like":state.affection,"health":state.health,"level":Double(state.level),"money":state.money,"food":state.food,"drink":state.drink,"feel":state.feeling,"strength":state.strength]
        return values.allSatisfy { key,value in value >= bounds[key+"min",default:key=="money" ? -2147483648 : 0] && value <= bounds[key+"max",default:2147483647] }
    }
    public func matchesLow(state:PetState,kind:String) -> Bool {
        let value=kind=="food" ? state.food : state.drink
        let high=state.mood == .happy || state.mood == .normal
        let tier=state.affection<40 ? 0 : state.affection<70 ? 1 : state.affection<100 ? 2 : 3
        let strength=high ? (value>60 ? "L" : value>40 ? "M" : "S") : (value>40 ? "L" : value>20 ? "M" : "S")
        return self.kind==kind && value < (high ? 70 : 60) && lowMode==(high ? "H" : "L") && severity==strength && (high ? like<=tier : like<tier)
    }
    public func rendered(state:PetState) -> String {
        let values=["name":state.name,"food":String(format:"%.0f",state.food),"drink":String(format:"%.0f",state.drink),"feel":String(format:"%.0f",state.feeling),"strength":String(format:"%.0f",state.strength),"money":String(format:"%.0f",state.money),"level":String(state.level),"health":String(format:"%.0f",state.health),"hostname":"主人"]
        return values.reduce(text) { $0.replacingOccurrences(of:"{"+$1.key+"}",with:$1.value) }
    }
}
public struct PetDialogueCatalog:Codable,Sendable {
    public var version:Int
    public var tags:[String]
    public var entries:[PetTextEntry]
    public static func load(from url:URL) throws -> Self {
        let result=try JSONDecoder().decode(Self.self,from:Data(contentsOf:url));try result.validate();return result
    }
    public func validate() throws {
        guard version==1,!tags.isEmpty,Set(entries.map(\.id)).count==entries.count else { throw PetSaveError.invalidDocument }
        let keys=Set(["like","health","level","money","food","drink","feel","strength"].flatMap { [$0+"min",$0+"max"] })
        for e in entries {
            guard !e.id.isEmpty,!e.text.isEmpty,e.text.count<=5000,["click","food","drink"].contains(e.kind),(0...15).contains(e.mode),(0...15).contains(e.dayTime),(0...3).contains(e.like),e.effects.isValid,e.bounds.allSatisfy({ keys.contains($0.key) && $0.value.isFinite }),["Nomal","Work","Sleep","Travel","Empty"].contains(e.workState) else { throw PetSaveError.invalidDocument }
            for key in ["like","health","level","money","food","drink","feel","strength"] {
                guard e.bounds[key+"min",default:key=="money" ? -2147483648 : 0] <= e.bounds[key+"max",default:2147483647] else { throw PetSaveError.invalidDocument }
            }
            if e.kind != "click", !(["H","L"].contains(e.lowMode ?? "") && ["L","M","S"].contains(e.severity ?? "")) { throw PetSaveError.invalidDocument }
        }
    }
}
public final class PetDialogue {
    private let catalog:PetDialogueCatalog
    private let clock:any PetClock
    private var random:any PetRandom
    private var lastClick:TimeInterval?
    private var previous:TimeInterval
    private var nextLow:TimeInterval
    private var foodCount=20,drinkCount=20
    public init(catalog:PetDialogueCatalog,clock:any PetClock=SystemPetClock(),random:any PetRandom=SeededPetRandom(seed:UInt64.random(in:0...UInt64.max))) {
        self.catalog=catalog;self.clock=clock;self.random=random;previous=clock.now;nextLow=previous+15
    }
    public func resetTiming() { previous=clock.now;nextLow=previous+15 }
    private func index(_ count:Int) -> Int {
        let value=random.unit(),unit=value.isFinite ? min(1.0.nextDown,max(0,value)) : 0
        return min(count-1,Int(unit*Double(count)))
    }
    private func tagged(_ entry:PetTextEntry) -> Bool { !Set(entry.tags).isDisjoint(with:catalog.tags) }
    private func choose(_ entries:[PetTextEntry]) -> PetTextEntry? { entries.isEmpty ? nil : entries[index(entries.count)] }
    public func click(state:PetState,gameplay:PetCatalog,hour:Int) -> PetTextEntry? {
        let now=clock.now
        guard now.isFinite else { return nil }
        if let lastClick, now >= lastClick, now-lastClick<=20 { return nil }
        lastClick=now
        let activityName=state.activity.flatMap { gameplay.activity($0.activityID)?.name }
        return choose(catalog.entries.filter { tagged($0) && $0.matchesClick(state:state,activityName:activityName,hour:hour) })
    }
    public func automatic(state:PetState,eligible:Bool) -> PetTextEntry? {
        let now=clock.now,delta=now-previous
        guard now.isFinite,delta>=0,delta<=30 else { resetTiming();return nil }
        previous=now
        guard now>=nextLow else { return nil };nextLow=now+15
        guard eligible else { return nil }
        let high=state.mood == .happy || state.mood == .normal
        for kind in ["food","drink"] {
            guard (kind=="food" ? state.food : state.drink) < (high ? 70 : 60) else { continue }
            let count=kind=="food" ? foodCount : drinkCount
            let trigger=index(max(1,count))==0
            if kind=="food" { foodCount=trigger ? 200 : max(1,foodCount-1) }
            else { drinkCount=trigger ? 200 : max(1,drinkCount-1) }
            if trigger { return choose(catalog.entries.filter { tagged($0) && $0.matchesLow(state:state,kind:kind) }) }
        }
        return nil
    }
}
