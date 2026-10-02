// iPet: native schedule adaptation of VPet ScheduleTask and winWorkMenu.
// SPDX-License-Identifier: Apache-2.0
import Foundation

public struct PetScheduleEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public var activityID: String?
    public var multiplier: Int
    public var waitMinutes: Int?
    public func validate() throws {
        guard (1...1_000_000_000_000).contains(id), (1...400).contains(multiplier) else { throw PetSaveError.invalidState }
        if let activityID {
            guard !activityID.isEmpty, activityID.count<=300, waitMinutes==nil else { throw PetSaveError.invalidState }
        } else {
            guard let waitMinutes, (1...1440).contains(waitMinutes), multiplier==1 else { throw PetSaveError.invalidState }
        }
    }
}
public enum PetScheduleEdit: Sendable {
    case appendActivity(String, multiplier:Int)
    case appendWait(minutes:Int)
    case insertWait(before:Int, minutes:Int)
    case setWait(Int, minutes:Int)
    case remove(Int)
    case move(Int, offset:Int)
}
/// Queue editor; PetEngine owns execution and versioned user-save integration.
/// IDs survive reorder/removal; unknown activity IDs survive decoding for explicit diagnostics.
public struct PetScheduleQueue: Codable, Equatable, Sendable {
    public private(set) var entries: [PetScheduleEntry] = []
    public private(set) var nextID = 1
    public init() {}
    private enum CodingKeys:String,CodingKey { case entries,nextID }
    public init(from decoder:any Decoder) throws {
        let container=try decoder.container(keyedBy:CodingKeys.self)
        entries=try container.decode([PetScheduleEntry].self,forKey:.entries)
        nextID=try container.decode(Int.self,forKey:.nextID)
        try validate()
    }
    public func validate() throws {
        guard entries.count<=1000, (1...1_000_000_000_001).contains(nextID),
              Set(entries.map(\.id)).count==entries.count,
              entries.allSatisfy({ $0.id<nextID }) else { throw PetSaveError.invalidState }
        for entry in entries { try entry.validate() }
    }
    /// Transactional editor; never renews contracts, spends currency or starts activities.
    @discardableResult public mutating func edit(_ command:PetScheduleEdit,state:PetState,catalog:PetCatalog,now:Date,locked:Bool=false) -> PetCommandResult {
        func response(_ accepted:Bool,_ message:String) -> PetCommandResult { PetCommandResult(accepted:accepted,message:message) }
        guard !locked else { return response(false,"请先停止日程，再修改队列。") }
        do { try validate();try state.validate();try catalog.validate() }
        catch { return response(false,"日程或玩法数据不合法，未修改队列。") }
        var next=self
        do {
            switch command {
            case .appendActivity(let id,let multiplier):
                guard let base=catalog.activity(id),let effective=base.multiplied(by:multiplier) else { return response(false,"活动或倍率不可用。") }
                guard multiplier<=base.maximumMultiplier(level:state.level),state.level>=effective.levelLimit else { return response(false,"宠物等级不足以选择此活动倍率。") }
                if base.kind == .play {
                    guard state.level>=15 else { return response(false,"娱乐日程需要宠物15级。") }
                } else {
                    guard let contract=state.package(base.kind),contract.isActive(at:now) else { return response(false,"请先签署有效的\(base.kind.title)套餐。") }
                    guard contract.level>=effective.levelLimit else { return response(false,"套餐授权等级不足，需要等级\(effective.levelLimit)。") }
                }
                try next.insert(PetScheduleEntry(id:next.nextID,activityID:id,multiplier:multiplier),at:next.entries.count)
            case .appendWait(let minutes):
                guard (1...1440).contains(minutes) else { return response(false,"等待时间须为1至1440分钟。") }
                if let last=next.entries.indices.last,let existing=next.entries[last].waitMinutes {
                    next.entries[last].waitMinutes=existing+minutes
                } else {
                    try next.insert(PetScheduleEntry(id:next.nextID,multiplier:1,waitMinutes:minutes),at:next.entries.count)
                }
            case .insertWait(let before,let minutes):
                guard let index=next.entries.firstIndex(where:{ $0.id==before }), (1...1440).contains(minutes) else { return response(false,"插入位置或等待时间不可用。") }
                try next.insert(PetScheduleEntry(id:next.nextID,multiplier:1,waitMinutes:minutes),at:index)
            case .setWait(let id,let minutes):
                guard (1...1440).contains(minutes),let index=next.entries.firstIndex(where:{ $0.id==id }),next.entries[index].waitMinutes != nil else { return response(false,"等待项目或时长不可用。") }
                next.entries[index].waitMinutes=minutes
            case .remove(let id):
                guard let index=next.entries.firstIndex(where:{ $0.id==id }) else { return response(false,"日程项目不存在。") }
                try next.mergeNeighbors(at:index)
                next.entries.remove(at:index)
            case .move(let id,let offset):
                guard offset == -1 || offset == 1,let index=next.entries.firstIndex(where:{ $0.id==id }) else { return response(false,"移动位置不可用。") }
                if index+offset<0 || index+offset>=next.entries.count { return response(true,"项目已在队列边界。") }
                let entry=next.entries[index]
                try next.mergeNeighbors(at:index)
                next.entries.remove(at:index)
                next.entries.insert(entry,at:min(max(index+offset,0),next.entries.count))
            }
            try next.validate()
        } catch { return response(false,"日程数量、等待时长或编号达到上限，未修改队列。") }
        self=next
        return response(true,"日程队列已更新。")
    }
    mutating func setMultiplier(_ multiplier:Int,for id:Int) throws {
        guard (1...400).contains(multiplier),let index=entries.firstIndex(where: { $0.id==id }),entries[index].activityID != nil else { throw PetSaveError.invalidState }
        entries[index].multiplier=multiplier
    }
    private mutating func insert(_ entry:PetScheduleEntry,at index:Int) throws {
        guard entries.count<1000,nextID<=1_000_000_000_000 else { throw PetSaveError.invalidState }
        try entry.validate();entries.insert(entry,at:index);nextID+=1
    }
    private mutating func mergeNeighbors(at index:Int) throws {
        guard index>0,index+1<entries.count,
              let previous=entries[index-1].waitMinutes,let next=entries[index+1].waitMinutes else { return }
        // winWorkMenu merges the two neighbors before removing/moving the selected item.
        guard previous+next<=1440 else { throw PetSaveError.invalidState }
        entries[index-1].waitMinutes=previous+next;entries.remove(at:index+1)
    }
}
