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
    public private(set) var lastUsedItem:ItemDefinition?
    public private(set) var state: PetState
    public private(set) var simulationEnabled=true
    public private(set) var fixedMood:PetMood = .normal
    public var presentationMood:PetMood { simulationEnabled ? state.mood:fixedMood }
    public func configureSimulation(enabled:Bool,fixedMood:PetMood) {
        if simulationEnabled && !enabled { stopSchedule("养成已关闭，日程已停止。");stopActivity(.manual);state.resting=false }
        if simulationEnabled != enabled { resetClock();lastInteraction=activeSeconds }
        simulationEnabled=enabled;self.fixedMood=fixedMood
    }
    private let clock: any PetClock
    private var random: any PetRandom
    private let originalCatalog:PetCatalog
    public private(set) var catalog:PetCatalog
    public private(set) var automaticItemPricing=false
    public func configureItemPricing(enabled:Bool) throws {
        let candidate=try PetItemPricing.catalog(originalCatalog,enabled:enabled)
        catalog=candidate;automaticItemPricing=enabled
    }
    private let wallClock: any PetWallClock
    private var events: [PetEvent] = []
    private var reportedGrowth:PetDesktopGrowth?
    private var previous: TimeInterval
    private var remainder = 0.0
    private var activeSeconds = 0.0
    private var evaluation=PetEvaluation()
    private var lastInteraction = 0.0
    public init(state: PetState = PetState(), clock: any PetClock = SystemPetClock(), random: any PetRandom = SeededPetRandom(seed: UInt64.random(in: 0...UInt64.max)), catalog: PetCatalog = PetCatalog(), wallClock: any PetWallClock = SystemPetWallClock()) {
        originalCatalog=catalog;self.catalog=catalog; self.wallClock=wallClock
        self.state = state; reportedGrowth=state.growth; self.clock = clock; self.random = random; previous = clock.now
        var progress=state.progress ?? PetProgress();evaluation.begin(progress:&progress,now:wallClock.now);self.state.progress=progress
    }
    public func recordPinchStart() { updateProgress { $0.increment("stat_touch_head");$0.increment("stat_touch_body") } }
    public func recordInteraction() { lastInteraction = activeSeconds }
    public func resetClock() { previous = clock.now; remainder = 0 }
    public func tick() {
        let current = clock.now, delta = current - previous
        previous = current
        guard simulationEnabled else { remainder=0;return }
        // Never catch up a long suspension, sleep, or a backwards clock jump.
        guard delta.isFinite, delta >= 0, delta <= 30 else { remainder = 0; return }
        let waiting=state.schedule.flatMap { $0.isRunning && !$0.isPaused && ($0.phase == .waiting || $0.phase == .handoff) ? $0:nil }
        var remaining=delta
        while remaining > 0 {
            var chunk=min(remaining,15-remainder)
            if let session=state.activity, !session.isPaused, let work=catalog.activity(for:session) {
                let left=work.durationSeconds-session.elapsedSeconds
                if left <= 0 { stopActivity(.completed); continue }
                chunk=min(chunk,left)
                state.activity?.elapsedSeconds += chunk
                updateProgress { $0.recordTime(kind:work.kind,seconds:chunk) }
            }
            remainder += chunk; remaining -= chunk
            if remainder >= 15 { remainder -= 15; activeSeconds += 15; step() }
        }
        if let waiting,let current=state.schedule,current.phase==waiting.phase,current.currentEntryID==waiting.currentEntryID,!current.isPaused {
            state.schedule?.remainingSeconds=max(0,current.remainingSeconds-delta)
            if state.schedule?.remainingSeconds==0 { dispatchSchedule() }
        }
    }
    @discardableResult public func send(_ command: PetCommand) -> PetAction {
        lastInteraction = activeSeconds
        switch command {
        case .touchHead, .touchBody:
            updateProgress { $0.increment(command.isHead ? "stat_touch_head":"stat_touch_body") }
            if simulationEnabled && state.strength >= 10 && state.feeling < state.feelingMax { state.changeStrength(-2); state.changeFeeling(1) }
            state.resting = false
            return command.isHead ? .head : .body
        case .touchPinch:
            if simulationEnabled && state.strength >= 10 && state.feeling < state.feelingMax { state.changeStrength(-2);state.changeFeeling(1) }
            return .pinch
        case .feed: eat(.meal); return .eat
        case .water: eat(.water); return .drink
        case .toggleRest: stopSchedule("手动休息，日程已停止。");stopActivity(.manual); state.resting.toggle(); return state.resting ? .sleep : .idle
        }
    }
    public func drainEvents() -> [PetEvent] {
        if let before=reportedGrowth,let after=state.growth,let change=PetGrowthFeedback(before:before,after:after) {
            events.append(.growthChanged(change))
        }
        reportedGrowth=state.growth
        let result=events;events.removeAll();return result
    }
    @discardableResult public func perform(_ command: PetEconomyCommand) -> PetCommandResult {
        do { try catalog.validate(); try state.validate() } catch { return PetCommandResult(accepted:false,message:"数据不合法，操作已拒绝。") }
        switch command {
        case .schedule(let command): return performSchedule(command)
        case .signPackage(let id,let level,let replace):
            return transactPackage { PetPackageRules.sign(state:&$0,id:id,level:level,replace:replace,catalog:catalog,now:wallClock.now) }
        case .renewPackages:
            return transactPackage { PetPackageRules.renew(state:&$0,catalog:catalog,now:wallClock.now) }
        case .setPackageAutoRenew(let kind,let enabled):
            return transactPackage { next in
                guard var contract=next.package(kind) else { return result(false,"没有此类已签套餐。") }
                contract.autoRenew=enabled;next.setPackage(contract,kind:kind)
                return PetPackageRules.renew(state:&next,catalog:catalog,now:wallClock.now)
            }
        case .startActivity(let id): return startActivity(id,multiplier:1)
        case .startMultipliedActivity(let id,let multiplier): return startActivity(id,multiplier:multiplier)
        case .stopActivity: stopActivity(.manual); return result(true,"活动已停止。")
        case .pauseActivity: if state.activity?.scheduleEntryID != nil { state.schedule?.isPaused=true };state.activity?.isPaused=true; return result(true,"活动已暂停。")
        case .resumeActivity:
            guard simulationEnabled else { return result(false,"请先启用养成，再继续活动。") }
            guard let session=state.activity, let work=catalog.activity(for:session) else { return result(false,"原活动不可用，可停止保留的会话。") }
            guard state.mood != .ill, state.level >= work.levelLimit,
                  let base=catalog.activity(session.activityID),session.effectiveMultiplier<=base.maximumMultiplier(level:state.level) else { return result(false,"当前状态或等级不能继续活动。") }
            state.activity?.isPaused=false; if state.activity?.scheduleEntryID != nil { state.schedule?.isPaused=false };resetClock(); lastInteraction=activeSeconds
            return result(true,"活动已继续。")
        case .buyItem(let id,let mode):
            return transactItem(id:id,purchase:true,mode:mode)
        case .useItem(let id): return transactItem(id:id,purchase:false,mode:.useImmediately)
        }
    }
    private func transactPackage(_ transaction:(inout PetState)->PetCommandResult) -> PetCommandResult {
        var next=state
        let response=transaction(&next)
        guard response.accepted else { return response }
        do { try next.validate() } catch { return result(false,"套餐操作产生不合法数据，已拒绝且未扣款。") }
        state=next;return response
    }
    private func startActivity(_ id:String,multiplier:Int,scheduleEntryID:Int?=nil) -> PetCommandResult {
        guard simulationEnabled else { return result(false,"请先启用养成，再开始活动。") }
        guard let base=catalog.activity(id) else { return result(false,"未知活动。") }
        guard let work=base.multiplied(by:multiplier) else { return result(false,"活动倍率或定义不合法。") }
        guard state.mood != .ill else { return result(false,"生病时不能开始活动，请休息或使用药品。") }
        guard multiplier<=base.maximumMultiplier(level:state.level),state.level>=work.levelLimit else { return result(false,"等级不足，需要等级 \(work.levelLimit)。") }
        if scheduleEntryID==nil { stopSchedule("已切换手动活动，日程已停止。") }
        if state.activity?.activityID == id { stopActivity(.manual);return result(true,"活动已停止。") }
        stopActivity(.manual);state.resting=false;state.activity=ActivitySession(activityID:id,multiplier:multiplier);state.activity?.scheduleEntryID=scheduleEntryID;lastInteraction=activeSeconds
        updateProgress { PetEvaluation.started(progress:&$0,work:work) }
        return result(true,"开始\(work.name)（\(multiplier)倍）。")
    }
    public func setInventoryFavorite(id:String,favorite:Bool) -> PetCommandResult {
        guard state.inventory[id,default:0]>0 else { return result(false,"背包没有该物品。") }
        var next=state
        do {
            var owned:PetInventoryMetadata
            if let existing=next.inventoryMetadata?[id] { owned=existing }
            else if let item=catalog.item(id) { owned=try PetInventoryMetadata(definition:item) }
            else { return result(false,"未知物品只有本机收藏偏好，暂无可保存参数。") }
            owned.star=favorite
            if next.inventoryMetadata==nil { next.inventoryMetadata=[:] }
            next.inventoryMetadata?[id]=owned;try next.validate()
        } catch { return result(false,"无法完整保存收藏参数，状态未改变。") }
        state=next;return result(true,favorite ? "已收藏物品。":"已取消收藏。")
    }
    /// Applies each unit through the same rule path as a single inventory use.
    public func useItems(id:String,count:Int) -> (used:Int,message:String) {
        guard count>0 else { return (0,"请选择正数数量。") }
        guard state.canUseInventory(id,catalog:catalog) else { return (0,"该库存物品当前无法使用。") }
        let available=state.inventory[id,default:0]
        guard available>0 else { return (0,"背包没有该物品。") }
        var used=0
        for _ in 0..<min(count,available) {
            let result=perform(.useItem(id))
            guard result.accepted else { return (used,result.message) }
            used+=1
        }
        return (used,"已使用 \(used) 件。")
    }
    private func transactItem(id: String, purchase: Bool, mode: PurchaseMode) -> PetCommandResult {
        guard let item=purchase ? catalog.item(id):state.inventoryDefinition(id,catalog:catalog) else { return result(false,"未知物品，操作已拒绝。") }
        if !purchase,!state.canUseInventory(id,catalog:catalog) { return result(false,"该库存物品当前无法使用。") }
        if purchase,mode == .useImmediately,!simulationEnabled {
            lastUsedItem=item;events.append(.itemUsed(id:id));return result(true,"养成已关闭，仅预览：\(item.name)。")
        }
        var next=state
        if purchase {
            if (item.price >= 1000 || item.experience >= 1000) && item.price >= next.money { return result(false,"此物品需要余额高于售价；低价物品可赊账。") }
            next.money -= item.price
            if mode == .inventory {
                guard (next.inventory[id] ?? 0) < 1000000 else { return result(false,"背包数量达到上限。") }
                if next.inventory[id,default:0]==0 || next.inventoryMetadata?[id]==nil {
                    do {
                        let parameters=try PetInventoryMetadata(definition:item)
                        if next.inventoryMetadata==nil { next.inventoryMetadata=[:] }
                        next.inventoryMetadata?[id]=parameters
                    } catch { return result(false,"物品参数无法完整保存，未扣款或入包。") }
                }
                next.inventory[id,default:0] += 1
            }
        } else {
            guard let count=next.inventory[id], count > 0 else { return result(false,"背包没有该物品。") }
            if count == 1 {
                next.inventory.removeValue(forKey:id);next.inventoryMetadata?.removeValue(forKey:id)
                if next.inventoryMetadata?.isEmpty==true { next.inventoryMetadata=nil }
            } else { next.inventory[id]=count-1 }
        }
        if mode == .useImmediately { PetItemRules.apply(item,to:&next,now:wallClock.now) }
        var progress=next.progress ?? PetProgress()
        if purchase { progress.purchased+=1;progress.spent+=item.price }
        if mode == .useImmediately { progress.used+=1;progress.recordUse(item) }
        next.progress=progress
        do { try next.validate() } catch { return result(false,"操作将产生不合法数据，已拒绝且未扣款。") }
        state=next
        if mode == .useImmediately {
            lastUsedItem=item
            lastInteraction=activeSeconds
            if state.mood == .ill, let session=state.activity, catalog.activity(for:session) != nil { stopActivity(.stateFailed) }
            events.append(.itemUsed(id:id))
        }
        return result(true,mode == .inventory ? "已买入背包：\(item.name)。" : "已使用：\(item.name)。")
    }
    private func result(_ accepted: Bool,_ message: String) -> PetCommandResult { PetCommandResult(accepted:accepted,message:message) }
    private func updateProgress(_ change:(inout PetProgress)->Void) {
        var progress=state.progress ?? PetProgress();change(&progress);state.progress=progress
    }
    private func stopActivity(_ reason: ActivityStopReason) {
        guard let session=state.activity else { return }
        var bonus=0.0
        if reason == .completed, let work=catalog.activity(for:session) {
            bonus=session.earned*work.finishBonus
            if work.kind == .work { state.money += bonus } else { state.experience += bonus }
        }
        updateProgress { $0.recordEnd(session:session,work:catalog.activity(for:session),reason:reason,bonus:bonus,date:wallClock.now) }
        if let work=catalog.activity(for:session) { updateProgress { PetEvaluation.ended(progress:&$0,kind:work.kind,reason:reason,earned:session.earned,bonus:bonus) } }
        state.activity=nil
        events.append(.activityStopped(id:session.activityID,reason:reason,earned:session.earned,bonus:bonus))
        if let owner=session.scheduleEntryID,let schedule=state.schedule,schedule.phase == .activity,schedule.currentEntryID==owner {
            guard let work=catalog.activity(for:session) else { stopSchedule("日程活动不可用，已停止。");return }
            // C# Work.Time is integer minutes: Time/2 truncates before comparing spendtime.
            let threshold=(work.durationSeconds/60).rounded(.towardZero)/2
            if session.elapsedSeconds/60 < threshold.rounded(.towardZero) { stopSchedule("活动未达到半程，日程已停止。") }
            else { state.schedule?.phase = .handoff;state.schedule?.isPaused=false;state.schedule?.remainingSeconds=30;notifySchedule("活动已结束，30秒后继续日程。") }
        }
    }
    @discardableResult public func applyDialogue(_ effects:PetDialogueEffects) -> Bool {
        applyDialogue(effects,selection:false)
    }
    @discardableResult public func applySelectionDialogue(_ effects:PetDialogueEffects) -> Bool {
        applyDialogue(effects,selection:true)
    }
    private func applyDialogue(_ effects:PetDialogueEffects,selection:Bool) -> Bool {
        guard effects.isValid else { return false }
        let before=state
        if selection {
            var progress=state.progress ?? PetProgress()
            for (key,value) in [("exp",effects.experience),("like",effects.affection),("money",effects.money)] where value != 0 {
                progress.increment("stat_say_"+key+(value>0 ? "_p":"_d"))
            }
            state.progress=progress
        }
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
        let sampledMood=state.mood
        let sm25=state.strengthMax*0.25,sm50=state.strengthMax*0.5,sm75=state.strengthMax*0.75
        releaseStores()
        if state.resting {
            state.changeStrength(t * 2); state.changeFood(t)
            if state.food <= sm25 { state.changeFood(t) } else if state.food >= sm75 { state.changeHealth(t * 2) }
            state.changeDrink(t)
            // Original uses >=25; its subsequent >=75 branch is unreachable.
            if state.drink >= sm25 { state.changeDrink(t) } else if state.drink >= sm75 { state.changeHealth(t * 2) }
            lastInteraction = activeSeconds
        } else if let session=state.activity, !session.isPaused, let work=catalog.activity(for:session) {
            let minutes=(activeSeconds-lastInteraction)/60
            let freedrop=minutes < 1 ? 0 : min(sqrt(minutes)*t/4,state.feelingMax/800)
            let gain=PetActivityRules.advance(state: &state,work:work,t:t,freedrop:freedrop,random:&random)
            state.activity?.earned += gain
            updateProgress { $0.recordGain(kind:work.kind,amount:gain) }
            if work.kind == .play { lastInteraction=activeSeconds }
        } else {
            var healthBonus = -2
            if state.food >= sm50 {
                state.changeFood(-t); state.changeStrength(t)
                if state.food >= sm75 { healthBonus += 1 + Int(random.unit() * 2) }
            } else if state.food <= sm25 { state.changeHealth(-random.unit() * t); healthBonus -= 2 }
            if state.drink >= sm50 {
                state.changeDrink(-t); state.changeStrength(t)
                if state.drink >= sm75 { healthBonus += 1 + Int(random.unit() * 2) }
            } else if state.drink <= sm25 { state.changeHealth(-random.unit() * t); healthBonus -= 2 }
            if healthBonus > 0 { state.changeHealth(Double(healthBonus) * t) }
            state.changeFood(-t); state.changeDrink(-t)
            let minutes = (activeSeconds - lastInteraction) / 60
            state.changeFeeling(-(minutes < 1 ? 0 : min(sqrt(minutes) * t / 4, state.feelingMax / 800)))
        }
        state.experience += t
        if state.feeling >= state.feelingMax*0.75 {
            if state.feeling >= state.feelingMax*0.90 { state.changeAffection(t) }
            state.experience += t * 2; state.changeHealth(t)
        } else if state.feeling <= 25 { state.changeAffection(-t); state.experience -= t }
        // Random.Next(0,1) is always zero in C#; do not add random health loss.
        if state.drink <= sm25 { state.experience -= t }
        updateProgress { $0.recordSample(state:state,catalog:catalog,mood:sampledMood) }
        var progress=state.progress ?? PetProgress();evaluation.advance(progress:&progress,now:wallClock.now,seconds:15);state.progress=progress
        if state.mood == .ill, let session=state.activity, catalog.activity(for:session) != nil { stopActivity(.stateFailed) }
    }
}
private extension PetCommand { var isHead: Bool { if case .touchHead = self { true } else { false } } }

private extension PetEngine {
    func notifySchedule(_ message:String) {
        state.schedule?.message=message
        events.append(.scheduleChanged(message:message))
    }
    func stopSchedule(_ message:String) {
        guard state.schedule?.isRunning == true else { return }
        state.activity?.scheduleEntryID=nil
        state.schedule?.phase = .stopped;state.schedule?.isPaused=false
        state.schedule?.currentEntryID=nil;state.schedule?.remainingSeconds=0;state.schedule?.nextIndex=0
        notifySchedule(message)
    }
    func performSchedule(_ command:PetScheduleCommand) -> PetCommandResult {
        switch command {
        case .edit(let edit):
            var schedule=state.schedule ?? PetSchedule()
            let response=schedule.queue.edit(edit,state:state,catalog:catalog,now:wallClock.now,locked:schedule.isRunning)
            if response.accepted { state.schedule=schedule }
            return response
        case .start:
            guard simulationEnabled else { return result(false,"请先启用养成，再开始日程。") }
            guard let schedule=state.schedule,!schedule.queue.entries.isEmpty else { return result(false,"请先添加日程项目。") }
            stopSchedule("日程重新开始。");stopActivity(.manual)
            state.schedule?.isPaused=false;state.schedule?.nextIndex=0
            resetClock();dispatchSchedule()
            // Dispatch can renew before rejecting an unavailable activity; always persist the attempt.
            return result(true,state.schedule?.message ?? "日程已启动。")
        case .stop:
            stopSchedule("日程已停止，保留当前活动。")
            return result(true,"日程已停止，保留当前活动。")
        case .pause:
            guard state.schedule?.isRunning == true else { return result(false,"日程尚未运行。") }
            state.schedule?.isPaused=true
            if state.activity?.scheduleEntryID != nil { state.activity?.isPaused=true }
            resetClock();notifySchedule("日程已暂停。")
            return result(true,"日程已暂停。")
        case .resume:
            guard simulationEnabled,state.schedule?.isRunning == true else { return result(false,"当前不能继续日程。") }
            if state.schedule?.phase == .activity {
                let response=perform(.resumeActivity)
                guard response.accepted else { return response }
            }
            state.schedule?.isPaused=false;resetClock();notifySchedule("日程已继续。")
            return result(true,"日程已继续。")
        }
    }
    func dispatchSchedule() {
        guard var schedule=state.schedule,!schedule.queue.entries.isEmpty else { return }
        // Close the expired wait before financial validation: zero is not a valid live wait.
        state.schedule?.phase = .stopped;state.schedule?.currentEntryID=nil
        state.schedule?.remainingSeconds=0;state.schedule?.isPaused=false
        _=transactPackage { PetPackageRules.renew(state:&$0,catalog:catalog,now:wallClock.now) }
        // A local copy describes the next item; no stale completed activity can advance it.
        if schedule.nextIndex>=schedule.queue.entries.count { schedule.nextIndex=0 }
        let entry=schedule.queue.entries[schedule.nextIndex]
        schedule.currentEntryID=entry.id;schedule.nextIndex+=1;schedule.isPaused=false;schedule.remainingSeconds=0
        if let minutes=entry.waitMinutes {
            schedule.phase = .waiting;schedule.remainingSeconds=Double(minutes)*60
            state.schedule=schedule;notifySchedule("日程等待\(minutes)分钟（不强制睡觉）。")
            return
        }
        // Keep stopped transient state coherent while checking and starting a new activity.
        schedule.phase = .stopped;schedule.currentEntryID=nil
        state.schedule=schedule
        func fail(_ text:String) {
            state.schedule?.phase = .stopped;state.schedule?.currentEntryID=nil
            state.schedule?.remainingSeconds=0;state.schedule?.nextIndex=0
            notifySchedule(text)
        }
        guard let id=entry.activityID,let base=catalog.activity(id) else { fail("日程活动不可用，已停止；项目仍保留。");return }
        if base.kind != .play {
            guard let contract=state.package(base.kind),contract.isActive(at:wallClock.now) else { fail("\(base.kind.title)套餐未激活，日程已停止。");return }
            guard contract.level>=base.levelLimit else { fail("套餐授权等级不足，日程已停止。");return }
        }
        var multiplier=entry.multiplier
        while multiplier>1 {
            guard let work=base.multiplied(by:multiplier) else { fail("日程倍率不可用，已停止。");return }
            if state.level>=work.levelLimit,multiplier<=base.maximumMultiplier(level:state.level) { break }
            multiplier-=1
        }
        do { try state.schedule?.queue.setMultiplier(multiplier,for:entry.id) }
        catch { fail("日程项目不合法，已停止。");return }
        let response=startActivity(id,multiplier:multiplier,scheduleEntryID:entry.id)
        guard response.accepted,state.activity?.scheduleEntryID==entry.id else { fail(response.message+" 日程已停止。");return }
        state.schedule?.phase = .activity;state.schedule?.currentEntryID=entry.id
        notifySchedule(response.message+(multiplier != entry.multiplier ? " 已按当前等级降低日程倍率。":""))
    }
}
