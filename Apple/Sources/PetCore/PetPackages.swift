// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct PetPackageDefinition:Codable,Equatable,Sendable,Identifiable {
    public var id,name,description:String
    public var kind:ActivityKind
    public var commission,unitPrice,levelRatio:Double
    public var durationDays:Int
    public init(id:String,name:String,description:String="",kind:ActivityKind,commission:Double,unitPrice:Double,levelRatio:Double,durationDays:Int) {
        self.id=id;self.name=name;self.description=description;self.kind=kind;self.commission=commission;self.unitPrice=unitPrice;self.levelRatio=levelRatio;self.durationDays=durationDays
    }
    public func validate() throws {
        guard !id.isEmpty,id.count<=300,!name.isEmpty,name.count<=100,description.count<=4096,kind != .play,
              commission.isFinite,(0...1).contains(commission),unitPrice.isFinite,(0...1e12).contains(unitPrice),
              levelRatio.isFinite,(1...1e6).contains(levelRatio),(1...36500).contains(durationDays) else { throw PetSaveError.invalidDocument }
    }
    public func quote(level:Int,now:Date) -> PetSignedPackage? {
        guard (1...100000).contains(level) else { return nil }
        do { try validate() } catch { return nil }
        let contract=PetSignedPackage(definitionID:id,name:name,description:description,kind:kind,commission:commission,
                                      price:unitPrice*(200*Double(level)-100),level:Int(Double(level)/levelRatio),
                                      endTime:now.addingTimeInterval(Double(durationDays)*86400))
        do { try contract.validate() } catch { return nil }
        return contract
    }
}
public struct PetSignedPackage:Codable,Equatable,Sendable {
    public var definitionID,name,description:String
    public var kind:ActivityKind
    public var commission,price:Double
    public var level:Int
    public var endTime:Date
    public var autoRenew=false
    public func isActive(at date:Date) -> Bool { date<endTime }
    public func validate() throws {
        guard !definitionID.isEmpty,definitionID.count<=300,!name.isEmpty,name.count<=100,description.count<=4096,kind != .play,
              commission.isFinite,(0...1).contains(commission),price.isFinite,(0...1e12).contains(price),
              (0...100000).contains(level),endTime.timeIntervalSince1970.isFinite,abs(endTime.timeIntervalSince1970)<=1e12 else { throw PetSaveError.invalidState }
    }
}
public extension PetState {
    func package(_ kind:ActivityKind) -> PetSignedPackage? {
        switch kind { case .work:workPackage;case .study:studyPackage;case .play:nil }
    }
    mutating func setPackage(_ contract:PetSignedPackage,kind:ActivityKind) {
        switch kind { case .work:workPackage=contract;case .study:studyPackage=contract;case .play:break }
    }
}
public enum PetPackageRules {
    /// Preserve winWorkMenu's formula, including quoting from the authorized (not selected) level.
    public static func refund(contract:PetSignedPackage,catalog:PetCatalog,now:Date) -> Double {
        guard contract.isActive(at:now),let old=catalog.packageDefinition(contract.definitionID),old.kind==contract.kind,
              let quote=old.quote(level:contract.level,now:now) else { return 0 }
        let left=contract.endTime.timeIntervalSince(now)/86400/2
        guard left>0.5 else { return 0 }
        let value=quote.price*(Double(old.durationDays)-left)/Double(old.durationDays)
        return value.isFinite && value>=0 && value<=quote.price ? value:0
    }
    static func sign(state:inout PetState,id:String,level:Int,replace:Bool,catalog:PetCatalog,now:Date) -> PetCommandResult {
        guard let definition=catalog.packageDefinition(id) else { return result(false,"未识别套餐，操作已拒绝。") }
        guard (15...100000).contains(level),level%5==0,level<=state.level else { return result(false,"套餐需15级解锁，选择等级须为5的倍数且不超过当前等级。") }
        guard let contract=definition.quote(level:level,now:now) else { return result(false,"套餐报价或日期不合法。") }
        guard state.money>=contract.price else { return result(false,"金币不足，需先支付套餐全价，不能使用预计退款抵扣门槛。") }
        let previous=state.package(definition.kind)
        if previous?.isActive(at:now)==true && !replace { return result(false,"当前套餐仍有效，请确认替换。") }
        let refund=previous.map { Self.refund(contract:$0,catalog:catalog,now:now) } ?? 0
        state.money -= contract.price-refund;state.setPackage(contract,kind:definition.kind)
        let note=previous?.isActive(at:now)==true && catalog.packageDefinition(previous!.definitionID)==nil ? "旧套餐定义未识别，退款按0处理。":""
        return result(true,note+"已签署\(definition.name)，支付\(contract.price.formatted(.number.precision(.fractionLength(2))))金币，退款\(refund.formatted(.number.precision(.fractionLength(2))))金币。")
    }
    static func renew(state:inout PetState,catalog:PetCatalog,now:Date) -> PetCommandResult {
        var renewed=0
        for kind in [ActivityKind.work,.study] {
            guard let old=state.package(kind),old.autoRenew,!old.isActive(at:now),
                  let definition=catalog.packageDefinition(old.definitionID),definition.kind==kind,
                  let replacement=definition.quote(level:old.level,now:now),replacement.price<state.money else { continue }
            state.money -= replacement.price;state.setPackage(replacement,kind:kind);renewed+=1
        }
        return result(true,renewed>0 ? "已续费\(renewed)份套餐；按原规则重算授权等级，续费开关已关闭。":"没有符合续费条件的套餐；过期、已启用、定义可识别且余额严格高于新价时才续费。")
    }
    private static func result(_ accepted:Bool,_ message:String) -> PetCommandResult { PetCommandResult(accepted:accepted,message:message) }
}
