// SPDX-License-Identifier: Apache-2.0
/// Session feedback, separate from persisted progression and rewards.
public struct PetGrowthFeedback:Equatable,Sendable {
    public let beforeLevel,afterLevel,beforePrestige,afterPrestige,levelUps:Int
    public var didPrestige:Bool { afterPrestige>beforePrestige }
    public init?(before:PetDesktopGrowth,after:PetDesktopGrowth) {
        // First prestige completes 1000 thresholds; each later prestige completes
        // 1001, because its reset level is 100*p and its ceiling is 1000+100*p.
        func ordinal(_ growth:PetDesktopGrowth)->Int {
            growth.prestige == 0 ? growth.level-1:1000+(growth.prestige-1)*1001+growth.level-100*growth.prestige
        }
        let count=ordinal(after)-ordinal(before)
        guard count>0 else { return nil }
        beforeLevel=before.level;afterLevel=after.level
        beforePrestige=before.prestige;afterPrestige=after.prestige;levelUps=count
    }
    public func message(name:String)->String {
        if didPrestige { return "\(name)等级突破了：\(beforePrestige)阶 Lv\(beforeLevel) → \(afterPrestige)阶 Lv\(afterLevel)（共\(levelUps)级）。" }
        return "\(name)升级了：Lv\(beforeLevel) → Lv\(afterLevel)（共\(levelUps)级）。"
    }
}
