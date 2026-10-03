// iPet read-only Windows save inspection; see PHASE-4C and fixed upstream sources.
// SPDX-License-Identifier: Apache-2.0
import Foundation

/// A pet-field candidate is only a subset. There is deliberately no whole-save import API here.
public struct PetLegacySavePreview: Sendable {
    public struct Issue: Sendable {
        public enum Severity: String, Sendable { case warning, blocking }
        public let path: String
        public let message: String
        public let severity: Severity
    }
    public let sourceData: Data
    public let document: PetLegacyLPSDocument
    public let integrity: PetLegacyIntegrity.Result
    public let inventory: PetLegacyInventoryPreview
    public let statistics: PetLegacyStatisticsPreview
    public let petState: PetState?
    public let hostName: String?
    public let savedMode: String?
    public let issues: [Issue]
    public let omittedIssueCount: Int

    public init(data: Data) throws {
        sourceData=data;document=try PetLegacyLPSDocument.parse(data)
        integrity=PetLegacyIntegrity.inspect(document)
        inventory=PetLegacyInventoryPreview(document:document)
        statistics=PetLegacyStatisticsPreview(document:document)
        var mapper=Mapper(document:document,integrity:integrity);mapper.run()
        petState=mapper.state;hostName=mapper.hostName;savedMode=mapper.savedMode
        issues=mapper.issues;omittedIssueCount=mapper.omitted
    }
    private struct Mapper {
        let document:PetLegacyLPSDocument
        let integrity:PetLegacyIntegrity.Result
        var state:PetState?,hostName:String?,savedMode:String?
        var issues=[Issue](),omitted=0,invalid=false,consumed=Set<Int>()
        mutating func report(_ path:String,_ message:String,_ severity:Issue.Severity = .warning) {
            if issues.count<200 { issues.append(Issue(path:path,message:message,severity:severity)) }
            else { omitted+=1 }
        }
        mutating func field(_ line:PetLegacyLPSDocument.Line,_ key:String,ignoreCase:Bool=false) -> PetLegacyLPSDocument.Field? {
            let matches=line.fields.indices.filter { index in
                let bytes=line.fields[index].name.utf8
                if ignoreCase {
                    return bytes.map { (65...90).contains($0) ? $0+32:$0 }.elementsEqual(key.utf8.map { (65...90).contains($0) ? $0+32:$0 })
                }
                return bytes.elementsEqual(key.utf8)
            }
            consumed.formUnion(matches)
            if matches.count>1 { invalid=true;report("vpet."+key,"存在多个匹配字段，未选择其中一个冒充无歧义导入。",.blocking) }
            return matches.first.map { line.fields[$0] }
        }
        mutating func fixed(_ line:PetLegacyLPSDocument.Line,_ key:String,ignoreCase:Bool=false) -> Double {
            guard let item=field(line,key,ignoreCase:ignoreCase) else { report("vpet."+key,"原字段缺失，按桌面初始化值0预览。");return 0 }
            do { return try PetLegacyLPSDocument.storedFloat(item.rawInfo) }
            catch { invalid=true;report("vpet."+key,"不是受支持的规范固定点数值，未猜测或修复。",.blocking);return 0 }
        }
        mutating func integer(_ line:PetLegacyLPSDocument.Line,_ key:String,defaultValue:Int) -> Int {
            guard let item=field(line,key) else { report("vpet."+key,"原字段缺失，按桌面初始化值\(defaultValue)预览。");return defaultValue }
            guard let value=Int32(item.rawInfo),String(value)==item.rawInfo else { invalid=true;report("vpet."+key,"不是规范Int32等级字段。",.blocking);return defaultValue }
            return Int(value)
        }
        mutating func affectionLimit(_ line:PetLegacyLPSDocument.Line) -> Double? {
            guard let item=field(line,"LikabilityMax") else { report("vpet.LikabilityMax","原字段缺失，从初始化值100保留经验setter的上限增量。");return nil }
            // This annotated property is a plain double, unlike the ToFloat properties.
            let pattern="^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"
            guard item.rawInfo.range(of:pattern,options:.regularExpression) != nil,
                  let value=Double(item.rawInfo),value.isFinite,(0...1e12).contains(value) else {
                invalid=true;report("vpet.LikabilityMax","普通小数字段不合法，不按固定点或地区格式猜测。",.blocking);return 100
            }
            return value
        }
        mutating func run() {
            report("hash",integrity.message,integrity.status == .mismatch || integrity.status == .unsupported ? .blocking:.warning)
            let pets=document.lines.filter { $0.name.utf8.elementsEqual("vpet".utf8) }
            for line in document.lines where !line.name.utf8.elementsEqual("vpet".utf8) {
                if line.name.utf8.elementsEqual("hash".utf8) { continue }
                let message = line.name == "statistics" ? "已有独立只读类型化统计预览；整档统计应用、物品名称ID转换与历史汇总仍未接入。" : line.name.hasPrefix("item") ? "库存已提供独立只读参数预览，原生持久化与整档确认导入尚未接入。" : "原扩展数据尚未映射，完整源字节保留。"
                report(line.name,message,.blocking)
            }
            guard pets.count==1,let line=pets.first else { report("vpet","需要唯一的桌面宠物根行。",.blocking);return }
            guard line.rawInfo.isEmpty else { report("vpet","不支持含头部Info的旧格式，不猜测其含义。",.blocking);return }
            var pet=PetState()
            if let name=field(line,"name") { pet.name=name.info }
            else { pet.name="";invalid=true;report("vpet.name","缺少宠物名称。",.blocking) }
            hostName=field(line,"hostname")?.info ?? ""
            if hostName?.isEmpty == false { report("vpet.hostname","主人称呼已读取，尚未接入原生持久化与界面。",.blocking) }
            else { report("vpet.hostname","主人称呼为空或缺失，按原空值预览。") }
            let level=integer(line,"Level",defaultValue:1),prestige=integer(line,"LevelMax",defaultValue:0)
            let experience=fixed(line,"exp"),limit=affectionLimit(line)
            pet.money=fixed(line,"money")
            pet.strength=fixed(line,"strength",ignoreCase:true);pet.storedStrength=fixed(line,"StoreStrength",ignoreCase:true)
            pet.food=fixed(line,"strengthFood");pet.storedFood=fixed(line,"StoreStrengthFood")
            pet.drink=fixed(line,"strengthDrink");pet.storedDrink=fixed(line,"StoreStrengthDrink")
            pet.feeling=fixed(line,"feeling");pet.health=fixed(line,"health");pet.affection=fixed(line,"likability")
            if let mode=field(line,"mode") {
                savedMode=mode.info
                if !PetMood.allCases.contains(where:{ $0.rawValue.utf8.elementsEqual(mode.info.utf8) }) {
                    invalid=true;report("vpet.mode","不是受支持的原版模式名称，宠物候选不可用。",.blocking)
                }
            } else { savedMode="Nomal";report("vpet.mode","原字段缺失，按桌面初始化模式Nomal预览。") }
            for index in line.fields.indices where !consumed.contains(index) && !line.fields[index].name.utf8.elementsEqual("hash".utf8) { report("vpet."+line.fields[index].name,"尚未映射的宠物字段，源数据保留。",.blocking) }
            guard !invalid else { return }
            do {
                // Original load visits Exp before LikabilityMax. Its final serialized limit wins.
                var growth=try PetDesktopGrowth(level:level,prestige:prestige,experience:0,affectionMax:100)
                try growth.setExperience(experience)
                if growth.level != level || growth.prestige != prestige || growth.experience != experience { report("vpet.exp","按原经验setter推进等级/突破和剩余经验；独立好感上限按原字段是否存在处理。") }
                growth=try PetDesktopGrowth(level:growth.level,prestige:growth.prestige,experience:growth.experience,affectionMax:limit ?? growth.affectionMax)
                pet.growth=growth;pet.experience=growth.experience
                try pet.validate()
                if savedMode != pet.mood.rawValue { report("vpet.mode","原模式\(savedMode ?? "")保留用于核对；原生候选按当前属性重算为\(pet.mood.rawValue)。") }
                state=pet
            } catch { report("vpet","属性超出原生合法范围，未截断或重置；宠物候选不可用。",.blocking) }
        }
    }
}
