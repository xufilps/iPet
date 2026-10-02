// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import Foundation

public protocol PetClock { var now: TimeInterval { get } }
public struct SystemPetClock: PetClock { public init() {}; public var now: TimeInterval { ProcessInfo.processInfo.systemUptime } }
public protocol PetRandom { mutating func unit() -> Double }
public struct SeededPetRandom: PetRandom {
    private var seed: UInt64
    public init(seed: UInt64) { self.seed = seed }
    public mutating func unit() -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double(seed >> 11) / Double(UInt64(1) << 53)
    }
}
/// Serial simulation owner. Call from a single executor (the app uses MainActor).
public final class PetEngine {
    public private(set) var state: PetState
    private let clock: any PetClock
    private var random: any PetRandom
    public let catalog: PetCatalog
    private let wallClock: any PetWallClock
    private var events: [PetEvent] = []
    private var previous: TimeInterval
    private var remainder = 0.0
    private var activeSeconds = 0.0
    private var lastInteraction = 0.0
    public init(state: PetState = PetState(), clock: any PetClock = SystemPetClock(), random: any PetRandom = SeededPetRandom(seed: UInt64.random(in: 0...UInt64.max)), catalog: PetCatalog = PetCatalog(), wallClock: any PetWallClock = SystemPetWallClock()) {
        self.catalog=catalog; self.wallClock=wallClock
        self.state = state; self.clock = clock; self.random = random; previous = clock.now
    }
    public func recordInteraction() { lastInteraction = activeSeconds }
    public func resetClock() { previous = clock.now; remainder = 0 }
    public func tick() {
        let current = clock.now, delta = current - previous
        previous = current
        // Never catch up a long suspension, sleep, or a backwards clock jump.
        guard delta.isFinite, delta >= 0, delta <= 30 else { remainder = 0; return }
        var remaining=delta
        while remaining > 0 {
            var chunk=min(remaining,15-remainder)
            if let session=state.activity, !session.isPaused, let work=catalog.activity(session.activityID) {
                let left=work.durationSeconds-session.elapsedSeconds
                if left <= 0 { stopActivity(.completed); continue }
                chunk=min(chunk,left)
                state.activity?.elapsedSeconds += chunk
            }
            remainder += chunk; remaining -= chunk
            if remainder >= 15 { remainder -= 15; activeSeconds += 15; step() }
        }
    }
    @discardableResult public func send(_ command: PetCommand) -> PetAction {
        lastInteraction = activeSeconds
        switch command {
        case .touchHead, .touchBody:
            if state.strength >= 10 && state.feeling < 100 { state.changeStrength(-2); state.changeFeeling(1) }
            state.resting = false
            return command.isHead ? .head : .body
        case .feed: eat(.meal); return .eat
        case .water: eat(.water); return .drink
        case .toggleRest: stopActivity(.manual); state.resting.toggle(); return state.resting ? .sleep : .idle
        }
    }
    public func drainEvents() -> [PetEvent] { let result=events; events.removeAll(); return result }
    @discardableResult public func perform(_ command: PetEconomyCommand) -> PetCommandResult {
        do { try catalog.validate(); try state.validate() } catch { return PetCommandResult(accepted:false,message:"数据不合法，操作已拒绝。") }
        switch command {
        case .startActivity(let id):
            guard let work=catalog.activity(id) else { return result(false,"未知活动。") }
            guard state.mood != .ill else { return result(false,"生病时不能开始活动，请休息或使用药品。") }
            guard state.level >= work.levelLimit else { return result(false,"等级不足，需要等级 \(work.levelLimit)。") }
            if state.activity?.activityID == id { stopActivity(.manual); return result(true,"活动已停止。") }
            stopActivity(.manual); state.resting=false; state.activity=ActivitySession(activityID:id); lastInteraction=activeSeconds
            return result(true,"开始\(work.name)。")
        case .stopActivity: stopActivity(.manual); return result(true,"活动已停止。")
        case .pauseActivity: state.activity?.isPaused=true; return result(true,"活动已暂停。")
        case .resumeActivity:
            guard let session=state.activity, let work=catalog.activity(session.activityID) else { return result(false,"原活动不可用，可停止保留的会话。") }
            guard state.mood != .ill, state.level >= work.levelLimit else { return result(false,"当前状态或等级不能继续活动。") }
            state.activity?.isPaused=false; resetClock(); lastInteraction=activeSeconds
            return result(true,"活动已继续。")
        case .buyItem(let id,let mode):
            return transactItem(id:id,purchase:true,mode:mode)
        case .useItem(let id): return transactItem(id:id,purchase:false,mode:.useImmediately)
        }
    }
    private func transactItem(id: String, purchase: Bool, mode: PurchaseMode) -> PetCommandResult {
        guard let item=catalog.item(id) else { return result(false,"未知物品，操作已拒绝。") }
        var next=state
        if purchase {
            if (item.price >= 1000 || item.experience >= 1000) && item.price >= next.money { return result(false,"此物品需要余额高于售价；低价物品可赊账。") }
            next.money -= item.price
            if mode == .inventory {
                guard (next.inventory[id] ?? 0) < 1000000 else { return result(false,"背包数量达到上限。") }
                next.inventory[id,default:0] += 1
            }
        } else {
            guard let count=next.inventory[id], count > 0 else { return result(false,"背包没有该物品。") }
            if count == 1 { next.inventory.removeValue(forKey:id) } else { next.inventory[id]=count-1 }
        }
        if mode == .useImmediately { PetItemRules.apply(item,to:&next,now:wallClock.now) }
        do { try next.validate() } catch { return result(false,"操作将产生不合法数据，已拒绝且未扣款。") }
        state=next
        if mode == .useImmediately {
            lastInteraction=activeSeconds
            if state.mood == .ill, let session=state.activity, catalog.activity(session.activityID) != nil { stopActivity(.stateFailed) }
            events.append(.itemUsed(id:id))
        }
        return result(true,mode == .inventory ? "已买入背包：\(item.name)。" : "已使用：\(item.name)。")
    }
    private func result(_ accepted: Bool,_ message: String) -> PetCommandResult { PetCommandResult(accepted:accepted,message:message) }
    private func stopActivity(_ reason: ActivityStopReason) {
        guard let session=state.activity else { return }
        var bonus=0.0
        if reason == .completed, let work=catalog.activity(session.activityID) {
            bonus=session.earned*work.finishBonus
            if work.kind == .work { state.money += bonus } else { state.experience += bonus }
        }
        state.activity=nil
        events.append(.activityStopped(id:session.activityID,reason:reason,earned:session.earned,bonus:bonus))
    }
    @discardableResult public func applyDialogue(_ effects:PetDialogueEffects) -> Bool {
        guard effects.isValid else { return false }
        let before=state
        eat(effects.petFood);state.resting=before.resting;state.money += effects.money
        do { try state.validate() } catch { state=before;return false }
        recordInteraction();return true
    }
    private func eat(_ food: PetFood) {
        state.resting = false
        state.experience += food.experience
        state.changeStrength(food.strength / 2); state.storedStrength += food.strength / 2
        state.changeFood(food.food / 2); state.storedFood += food.food / 2
        state.changeDrink(food.drink / 2); state.storedDrink += food.drink / 2
        state.changeFeeling(food.feeling); state.changeHealth(food.health); state.changeAffection(food.affection)
    }
    private func releaseStores() {
        // Deliberately preserves GameSave.StoreTake's discarded <1 remainder.
        let strength = state.storedStrength / 10; state.storedStrength -= strength
        if abs(state.storedStrength) < 1 { state.storedStrength = 0 } else { state.changeStrength(strength) }
        let drink = state.storedDrink / 10; state.storedDrink -= drink
        if abs(state.storedDrink) < 1 { state.storedDrink = 0 } else { state.changeDrink(drink) }
        let food = state.storedFood / 10; state.storedFood -= food
        if abs(state.storedFood) < 1 { state.storedFood = 0 } else { state.changeFood(food) }
    }
    private func step() {
        let t = 0.05
        releaseStores()
        if state.resting {
            state.changeStrength(t * 2); state.changeFood(t)
            if state.food <= 25 { state.changeFood(t) } else if state.food >= 75 { state.changeHealth(t * 2) }
            state.changeDrink(t)
            // Original uses >=25; its subsequent >=75 branch is unreachable.
            if state.drink >= 25 { state.changeDrink(t) } else if state.drink >= 75 { state.changeHealth(t * 2) }
            lastInteraction = activeSeconds
        } else if let session=state.activity, !session.isPaused, let work=catalog.activity(session.activityID) {
            let minutes=(activeSeconds-lastInteraction)/60
            let freedrop=minutes < 1 ? 0 : min(sqrt(minutes)*t/4,100.0/800)
            let gain=PetActivityRules.advance(state: &state,work:work,t:t,freedrop:freedrop,random:&random)
            state.activity?.earned += gain
            if work.kind == .play { lastInteraction=activeSeconds }
        } else {
            var healthBonus = -2
            if state.food >= 50 {
                state.changeFood(-t); state.changeStrength(t)
                if state.food >= 75 { healthBonus += 1 + Int(random.unit() * 2) }
            } else if state.food <= 25 { state.changeHealth(-random.unit() * t); healthBonus -= 2 }
            if state.drink >= 50 {
                state.changeDrink(-t); state.changeStrength(t)
                if state.drink >= 75 { healthBonus += 1 + Int(random.unit() * 2) }
            } else if state.drink <= 25 { state.changeHealth(-random.unit() * t); healthBonus -= 2 }
            if healthBonus > 0 { state.changeHealth(Double(healthBonus) * t) }
            state.changeFood(-t); state.changeDrink(-t)
            let minutes = (activeSeconds - lastInteraction) / 60
            state.changeFeeling(-(minutes < 1 ? 0 : min(sqrt(minutes) * t / 4, 100.0 / 800)))
        }
        state.experience += t
        if state.feeling >= 75 {
            if state.feeling >= 90 { state.changeAffection(t) }
            state.experience += t * 2; state.changeHealth(t)
        } else if state.feeling <= 25 { state.changeAffection(-t); state.experience -= t }
        // Random.Next(0,1) is always zero in C#; do not add random health loss.
        if state.drink <= 25 { state.experience -= t }
        if state.mood == .ill, let session=state.activity, catalog.activity(session.activityID) != nil { stopActivity(.stateFailed) }
    }
}
private extension PetCommand { var isHead: Bool { if case .touchHead = self { true } else { false } } }
