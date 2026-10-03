// SPDX-License-Identifier: Apache-2.0
import Foundation

public struct PetSelectionEntry:Codable,Sendable,Identifiable {
    public var id,choose,text:String
    public var characterTags,conversationTags,toTags:[String]
    public var bounds:[String:Double]
    public var effects:PetDialogueEffects
    public init(id:String,choose:String,text:String,characterTags:[String]=["all"],conversationTags:[String]=[],toTags:[String]=[],bounds:[String:Double]=[:],effects:PetDialogueEffects=PetDialogueEffects()) {
        self.id=id;self.choose=choose;self.text=text;self.characterTags=characterTags;self.conversationTags=conversationTags;self.toTags=toTags;self.bounds=bounds;self.effects=effects
    }
    public func matches(state:PetState) -> Bool {
        let values=["like":state.affection,"health":state.health,"level":Double(state.level),"money":state.money,"food":state.food,"drink":state.drink,"feel":state.feeling,"strength":state.strength]
        return values.allSatisfy { key,value in value >= bounds[key+"min",default:key=="money" ? -2147483648:0] && value <= bounds[key+"max",default:2147483647] }
    }
    public func rendered(state:PetState) -> String { PetDialogueFormatting.render(text,state:state) }
    public var effectDescription:String {
        let values:[(String,Double)]=[("金币",effects.money),("经验",effects.experience),("体力",effects.strength),("饱腹",effects.food),("饮水",effects.drink),("心情",effects.feeling),("健康",effects.health),("好感",effects.affection)]
        let parts=values.filter { $0.1 != 0 }.map { $0.0+String(format:"%+.2g",$0.1) }
        return parts.isEmpty ? "无属性变化":parts.joined(separator:" · ")
    }
}
public struct PetSelectionCatalog:Codable,Sendable {
    public var version:Int
    public var tags:[String]
    public var entries:[PetSelectionEntry]
    public init(version:Int=1,tags:[String],entries:[PetSelectionEntry]) { self.version=version;self.tags=tags;self.entries=entries }
    public static func load(from url:URL) throws -> Self {
        let result=try JSONDecoder().decode(Self.self,from:Data(contentsOf:url));try result.validate();return result
    }
    public func validate() throws {
        let attrs=["like","health","level","money","food","drink","feel","strength"]
        let keys=Set(attrs.flatMap { [$0+"min",$0+"max"] })
        func validTags(_ tags:[String]) -> Bool { tags.count<=100 && tags.allSatisfy { !$0.isEmpty && $0.count<=300 } }
        guard version==1,!tags.isEmpty,validTags(tags),entries.count<=10000,Set(entries.map(\.id)).count==entries.count else { throw PetSaveError.invalidDocument }
        for e in entries {
            let f=e.effects
            guard !e.id.isEmpty,e.id.count<=300,!e.choose.isEmpty,e.choose.count<=5000,!e.text.isEmpty,e.text.count<=5000,
                  validTags(e.characterTags),validTags(e.conversationTags),validTags(e.toTags),f.isValid,
                  abs(f.money)<=1000,abs(f.experience)<=1000,f.experience.rounded(.towardZero)==f.experience,
                  abs(f.strength)<=1000,abs(f.food)<=1000,abs(f.drink)<=1000,abs(f.feeling)<=100,abs(f.health)<=100,abs(f.affection)<=50,
                  e.bounds.allSatisfy({ keys.contains($0.key) && $0.value.isFinite }) else { throw PetSaveError.invalidDocument }
            for key in attrs {
                guard e.bounds[key+"min",default:key=="money" ? -2147483648:0]<=e.bounds[key+"max",default:2147483647] else { throw PetSaveError.invalidDocument }
            }
        }
    }
}
/// Runtime-only choice pool. A single executor owns this session; original wall-clock expiry includes sleep.
public final class PetSelectionSession {
    private let catalog:PetSelectionCatalog
    private let clock:any PetWallClock
    private var random:any PetRandom
    private var said=Set<String>()
    public private(set) var choices:[PetSelectionEntry]=[]
    public private(set) var deadline:Date?
    private var lastAdd:Date?
    public init(catalog:PetSelectionCatalog,clock:any PetWallClock=SystemPetWallClock(),random:any PetRandom=SeededPetRandom(seed:UInt64.random(in:0...UInt64.max))) throws {
        try catalog.validate();self.catalog=catalog;self.clock=clock;self.random=random
    }
    public var remainingSeconds:Double { max(0,(deadline ?? clock.now).timeIntervalSince(clock.now)) }
    public var progress:Double {
        guard let deadline,let lastAdd,deadline>lastAdd else { return 1 }
        return min(1,max(0,1-remainingSeconds/deadline.timeIntervalSince(lastAdd)))
    }
    private var candidates:[PetSelectionEntry] { catalog.entries.filter { !Set($0.characterTags).isDisjoint(with:catalog.tags) } }
    private func draw(_ entries:inout [PetSelectionEntry]) -> PetSelectionEntry {
        let r=random.unit(),unit=r.isFinite ? min(1.0.nextDown,max(0,r)):0
        return entries.remove(at:min(entries.count-1,Int(unit*Double(entries.count))))
    }
    public func refresh(state:PetState) {
        let now=clock.now
        guard now.timeIntervalSince1970.isFinite,deadline == nil || deadline!<now else { return }
        deadline=now.addingTimeInterval(600);lastAdd=now;choices=[];said=[]
        var pool=candidates
        while !pool.isEmpty && choices.count<5 {
            let entry=draw(&pool)
            if !choices.contains(where:{ $0.choose==entry.choose }) && entry.matches(state:state) { choices.append(entry) }
        }
    }
    /// Apply must return the committed post-effect state, or nil. A refusal leaves the pool untouched.
    public func select(id:String,apply:(PetDialogueEffects)->PetState?) -> PetSelectionEntry? {
        guard clock.now.timeIntervalSince1970.isFinite,let index=choices.firstIndex(where:{ $0.id==id }),let deadline,
              let state=apply(choices[index].effects) else { return nil }
        let entry=choices.remove(at:index);said.insert(entry.choose)
        self.deadline=deadline.addingTimeInterval(300);lastAdd=clock.now
        if !entry.toTags.isEmpty {
            var pool=candidates.filter { !Set($0.conversationTags).isDisjoint(with:entry.toTags) }
            while !pool.isEmpty {
                let follow=draw(&pool)
                if !said.contains(follow.choose),!choices.contains(where:{ $0.choose==follow.choose }),follow.matches(state:state) {
                    choices.append(follow);break
                }
            }
        }
        refresh(state:state) // Original RelsSelect is called after every successful send.
        return entry
    }
}
