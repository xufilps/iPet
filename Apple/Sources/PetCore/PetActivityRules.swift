// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct ActivitySession: Codable, Equatable, Sendable {
    public var activityID: String
    public var multiplier:Int?
    public var scheduleEntryID:Int?
    public var effectiveMultiplier:Int { multiplier ?? 1 }
    public var elapsedSeconds = 0.0
    public var earned = 0.0
    public var isPaused = false
    public init(activityID: String,multiplier:Int=1) { self.activityID=activityID;self.multiplier=multiplier == 1 ? nil:multiplier }
}
public enum ActivityStopReason: String, Codable, Sendable { case completed, manual, stateFailed }
public enum PurchaseMode: Sendable { case useImmediately, inventory }
public enum PetEconomyCommand: Sendable { case schedule(PetScheduleCommand), signPackage(String,level:Int,replace:Bool), setPackageAutoRenew(ActivityKind,enabled:Bool), renewPackages, startActivity(String), startMultipliedActivity(String,multiplier:Int), stopActivity, resumeActivity, pauseActivity, buyItem(String, mode: PurchaseMode), useItem(String) }
public struct PetCommandResult: Sendable { public let accepted: Bool; public let message: String }
public enum PetEvent: Sendable { case scheduleChanged(message:String), activityStopped(id: String, reason: ActivityStopReason, earned: Double, bonus: Double), itemUsed(id: String) }
public protocol PetWallClock { var now: Date { get } }
public struct SystemPetWallClock: PetWallClock { public init() {} ; public var now: Date { Date() } }

enum PetActivityRules {
    static func advance(state: inout PetState, work: ActivityDefinition, t: Double, freedrop: Double, random: inout any PetRandom) -> Double {
        var needFood=t*work.strengthFood, needDrink=t*work.strengthDrink
        var efficiency=0.0, healthBonus = -2
        let sm25=state.strengthMax*0.25,sm60=state.strengthMax*0.6
        let substituteFood=needFood*0.3, substituteDrink=needDrink*0.3
        if state.strength > sm25+substituteFood+substituteDrink {
            state.changeStrength(-substituteFood-substituteDrink); efficiency += 0.1
            needFood -= substituteFood; needDrink -= substituteDrink
        }
        if state.food <= sm25 {
            state.changeFood(-needFood/2); efficiency += 0.2
            if state.strength >= needFood { state.changeStrength(-needFood); efficiency += 0.1 }
            healthBonus -= 2
        } else {
            state.changeFood(-needFood); efficiency += 0.4
            if state.food >= sm60 { healthBonus += 1+Int(random.unit()*2); efficiency += 0.1 }
        }
        if state.drink <= sm25 {
            state.changeDrink(-needDrink/2); efficiency += 0.2
            if state.strength >= needDrink { state.changeStrength(-needDrink); efficiency += 0.1 }
            healthBonus -= 2
        } else {
            state.changeDrink(-needDrink); efficiency += 0.4
            if state.drink >= sm60 { healthBonus += 1+Int(random.unit()*2); efficiency += 0.1 }
        }
        if healthBonus > 0 { state.changeHealth(Double(healthBonus)*t) }
        let gain=max(0,t*work.moneyBase*(2*efficiency-0.5))
        if work.kind == .work { state.money += gain } else { state.experience += gain }
        state.changeFeeling(work.kind == .play ? -work.feeling*t : -freedrop*(0.5+work.feeling/2))
        return gain
    }
}
