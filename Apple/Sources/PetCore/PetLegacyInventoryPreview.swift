// Source: VPet 1a06c598 Item/Food and MainWindow.ItemsAdd; read-only migration groundwork.
// SPDX-License-Identifier: Apache-2.0
import Foundation

public struct PetLegacyInventoryPreview: Sendable {
    public struct Food: Sendable {
        public let category: String
        public let experience: Int
        public let strength, food, drink, feeling, health, affection: Double
        public let graph: String?
    }
    public struct Item: Sendable {
        public let name, itemType, description, data: String
        public let image: String?
        public let price: Double
        public let count: Int
        public let canUse, star, isSingle, visibility: Bool
        public let food: Food?
        fileprivate var parameterKey: Data {
            // Encode an array so embedded delimiters and Unicode normalization cannot conflate parameters.
            var parts=[name,itemType,description,data,image == nil ? "null":"value",image ?? "",String(price),String(canUse),String(star),String(isSingle),String(visibility)]
            if let f=food {
                parts += [f.category,String(f.experience),String(f.strength),String(f.food),String(f.drink),String(f.feeling),String(f.health),String(f.affection),f.graph == nil ? "null":"value",f.graph ?? ""]
            }
            return (try? JSONSerialization.data(withJSONObject:parts)) ?? Data()
        }
    }
    public struct Record: Sendable {
        public let sourceLine: PetLegacyLPSDocument.Line
        public let item: Item?
        fileprivate let extraParameters: Data
    }
    /// What the original name-only ItemsAdd would combine; records themselves remain separate.
    public struct Merge: Sendable {
        public let name: String
        public let recordIndices: [Int]
        public let totalCount: Int64
        public let hasParameterConflict: Bool
    }
    public let records: [Record]
    public let merges: [Merge]
    public let issues: [PetLegacySavePreview.Issue]
    public let omittedIssueCount: Int

    public init(document: PetLegacyLPSDocument) {
        var mapper=Mapper()
        var seen=Set<Data>()
        for line in document.lines where line.name.utf8.starts(with:"item".utf8) {
            mapper.map(line)
            if !seen.insert(Data(line.name.utf8)).inserted { mapper.report("","重复物品根行，原Data字典加载有歧义；全部源记录保留。",.blocking) }
        }
        mapper.merge()
        records=mapper.records;merges=mapper.merges;issues=mapper.issues;omittedIssueCount=mapper.omitted
    }
    private struct Mapper {
        var records=[Record](),merges=[Merge](),issues=[PetLegacySavePreview.Issue](),omitted=0
        var line:PetLegacyLPSDocument.Line?,consumed=Set<Int>(),invalid=false
        mutating func report(_ key:String,_ message:String,_ severity:PetLegacySavePreview.Issue.Severity = .warning) {
            let path=(line?.name ?? "inventory")+(key.isEmpty ? "":"."+key)
            if issues.count<200 { issues.append(.init(path:path,message:message,severity:severity)) } else { omitted+=1 }
        }
        static func lowerASCII(_ value:String) -> [UInt8] { value.utf8.map { (65...90).contains($0) ? $0+32:$0 } }
        mutating func field(_ key:String,ignoreCase:Bool=true) -> PetLegacyLPSDocument.Field? {
            guard let line else { return nil }
            let matches=line.fields.indices.filter { i in
                ignoreCase ? Self.lowerASCII(line.fields[i].name)==Self.lowerASCII(key) : line.fields[i].name.utf8.elementsEqual(key.utf8)
            }
            consumed.formUnion(matches)
            if matches.count>1 { invalid=true;report(key,"重复匹配字段，未选取某条作为无歧义参数。",.blocking) }
            if matches.isEmpty { report(key,"缺失字段，按原物品初始化值预览。") }
            return matches.first.map { line.fields[$0] }
        }
        mutating func string(_ key:String,defaultValue:String?="",ignoreCase:Bool=true) -> String? {
            guard let value=field(key,ignoreCase:ignoreCase) else { return defaultValue }
            return value.rawInfo == "/null" ? nil:value.info
        }
        mutating func number(_ key:String) -> Double {
            guard let field=field(key) else { return 0 }
            let raw=field.info
            let pattern="^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"
            guard raw.range(of:pattern,options:.regularExpression) != nil,let value=Double(raw),value.isFinite,abs(value)<=1e12 else {
                invalid=true;report(key,"不支持的普通Double（不按宠物固定点或地区格式猜测）。",.blocking);return 0
            }
            return value
        }
        mutating func integer(_ key:String,defaultValue:Int) -> Int {
            guard let field=field(key) else { return defaultValue }
            guard let value=Int32(field.info),String(value)==field.info else { invalid=true;report(key,"不支持的规范Int32数值。",.blocking);return defaultValue }
            return Int(value)
        }
        mutating func bool(_ key:String,defaultValue:Bool) -> Bool {
            guard let field=field(key) else { return defaultValue }
            switch Self.lowerASCII(field.info) {
            case Array("true".utf8):return true
            case Array("false".utf8):return false
            default:invalid=true;report(key,"不支持的布尔值，不将数字猜为开关。",.blocking);return defaultValue
            }
        }
        mutating func map(_ source:PetLegacyLPSDocument.Line) {
            line=source;consumed=[];invalid=false
            if !source.rawInfo.isEmpty || !source.rawText.isEmpty { report("","物品行头/正文尚无类型映射，原记录保留。",.blocking) }
            let name=string("name",ignoreCase:false),type=string("itemtype",defaultValue:"Item",ignoreCase:false)
            if name?.isEmpty != false || type == nil { invalid=true;report("name","名称为空或类型为null，候选不可用。",.blocking) }
            let image=string("Image",defaultValue:nil),price=number("Price"),description=string("Desc"),count=integer("Count",defaultValue:1),data=string("Data")
            let canUse=bool("CanUse",defaultValue:true),star=bool("Star",defaultValue:false),single=bool("IsSingle",defaultValue:false),visible=bool("Visibility",defaultValue:true)
            if description == nil || data == nil { invalid=true;report("Data","null描述/自定义数据尚不支持原生表示，源记录保留。",.blocking) }
            if count<=0 { report("Count","保留原非正数量；不套用8/9月临时修补。") }
            var food:Food?
            if type?.utf8.elementsEqual("Food".utf8) == true {
                let categories=["Food","Star","Meal","Snack","Drink","Functional","Drug","Gift"]
                var category="Food"
                if let value=field("Type") {
                    if let match=categories.first(where: { $0.utf8.elementsEqual(value.info.utf8) }) { category=match }
                    else if let n=Int32(value.info),String(n)==value.info,categories.indices.contains(Int(n)) { category=categories[Int(n)] }
                    else { invalid=true;report("Type","未知或非规范食物枚举，未猜测类别。",.blocking) }
                }
                let exp=integer("Exp",defaultValue:0),strength=number("Strength"),satiety=number("StrengthFood"),drink=number("StrengthDrink"),feeling=number("Feeling"),health=number("Health"),affection=number("Likability"),graph=string("Graph",defaultValue:nil)
                food=Food(category:category,experience:exp,strength:strength,food:satiety,drink:drink,feeling:feeling,health:health,affection:affection,graph:graph)
            } else if type?.utf8.elementsEqual("Item".utf8) != true { report("itemtype","未知物品类型依赖原插件，保留基类参数但不可执行或当内置食物。",.blocking) }
            for i in source.fields.indices where !consumed.contains(i) { report(source.fields[i].name,"未映射字段，原值保留。",.blocking) }
            let item=invalid ? nil:Item(name:name ?? "",itemType:type ?? "",description:description ?? "",data:data ?? "",image:image,price:price,count:count,canUse:canUse,star:star,isSingle:single,visibility:visible,food:food)
            let extra=[source.rawInfo,source.rawText]+source.fields.indices.filter { !consumed.contains($0) }.flatMap { [source.fields[$0].name,source.fields[$0].rawInfo] }
            records.append(Record(sourceLine:source,item:item,extraParameters:(try? JSONSerialization.data(withJSONObject:extra)) ?? Data()))
        }
        mutating func merge() {
            line=nil
            var groups=[Data:[Int]](),order=[Data]()
            for i in records.indices {
                guard let item=records[i].item else { continue }
                let key=Data(item.name.utf8)
                if groups[key]==nil { order.append(key) }
                groups[key,default:[]].append(i)
            }
            for key in order {
                guard let indices=groups[key],indices.count>1,let first=records[indices[0]].item else { continue }
                var total:Int64=0
                for i in indices { total+=Int64(records[i].item!.count) }
                let firstKey=first.parameterKey,firstExtra=records[indices[0]].extraParameters
                let conflict=indices.dropFirst().contains { records[$0].item!.parameterKey != firstKey || records[$0].extraParameters != firstExtra }
                merges.append(Merge(name:first.name,recordIndices:indices,totalCount:total,hasParameterConflict:conflict))
                if total<Int64(Int32.min) || total>Int64(Int32.max) { report(first.name,"原名称合并数量超出Int32，未模拟溢出或修补。",.blocking) }
                report(first.name,conflict ? "原版按名称合并并丢弃后件不同参数；预览保留各件，不静默合并。":"原版按名称合并数量并保留首件参数；预览保留各源记录。",conflict ? .blocking:.warning)
            }
        }
    }
}
