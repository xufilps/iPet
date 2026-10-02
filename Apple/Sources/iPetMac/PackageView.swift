// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore
struct PackageView:View {
    @ObservedObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text("套餐用于后续日程授权，当前手动活动无需套餐。原版此基线只展示抽成字段，未实际扣除活动收益。").font(.caption).foregroundStyle(.secondary)
            Text("续费在主动检查或切换开关时尝试；成功后按原规则降低授权等级并关闭开关。套餐期限按墙钟计算，过期本身不会扣款。").font(.caption).foregroundStyle(.secondary)
            ForEach([ActivityKind.work,.study],id:\.self) { PackageGroup(model:model,kind:$0) }
            if model.packageWriteFailed {
                Text("套餐变更尚未保存，后续套餐操作已暂停。重试仅保存当前状态，不重放签署或续费。").font(.caption).foregroundStyle(.orange)
                Button("重试保存当前状态") { model.save() }
            }
            Button("检查已启用的到期续费") { model.perform(.renewPackages) }.disabled(!model.packageOperationsEnabled)
        }
    }
}
private struct PackageGroup:View {
    @ObservedObject var model:AppModel
    let kind:ActivityKind
    @State private var selectedID=""
    @State private var level=15
    private var choices:[PetPackageDefinition] { model.catalog.packageDefinitions.filter { $0.kind==kind } }
    private var definition:PetPackageDefinition? { choices.first { $0.id==selectedID } ?? choices.first }
    private var maximum:Int { max(15,min(100000,model.state.level)/5*5) }
    private var selectedLevel:Int { min(maximum,max(15,level)) }
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text("\(kind.title)套餐").font(.headline)
            if let current=model.state.package(kind) {
                Text("\(current.name) · \(current.isActive(at:Date()) ? "有效":"已到期") · 授权等级 \(current.level)")
                Text("到期 \(current.endTime.formatted(date:.abbreviated,time:.shortened)) · 签署价格 \(current.price.formatted(.number.precision(.fractionLength(2)))) 金币 · \(kind == .work ? "抽成":"学习比例") \((kind == .work ? current.commission:1-current.commission).formatted(.percent.precision(.fractionLength(0))))")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("启用一次到期续费",isOn:Binding(get:{ model.state.package(kind)?.autoRenew ?? false },set:{ model.perform(.setPackageAutoRenew(kind,enabled:$0)) }))
                    .disabled(!model.packageOperationsEnabled)
                if model.catalog.packageDefinition(current.definitionID)==nil {
                    Text("套餐定义未识别，资料仍保留，无法续费；替换时退款按0处理。").font(.caption).foregroundStyle(.orange)
                } else if current.level==0 {
                    Text("授权等级已降至0，无法继续续费，请重新签署套餐。").font(.caption).foregroundStyle(.orange)
                }
            } else { Text("尚未签署此类套餐。").foregroundStyle(.secondary) }
            if let definition {
                Picker("可用套餐",selection:Binding(get:{ self.definition?.id ?? "" },set:{ selectedID=$0 })) {
                    ForEach(choices) { Text($0.name).tag($0.id) }
                }
                if model.state.level>=15 { Stepper("签署等级 \(selectedLevel)",value:$level,in:15...maximum,step:5) }
                else { Text("达到15级后可签署套餐。").font(.caption).foregroundStyle(.secondary) }
                Text(definition.description).font(.caption)
                if let quote=definition.quote(level:selectedLevel,now:Date()) {
                    Text("全价 \(quote.price.formatted(.number.precision(.fractionLength(2)))) 金币 · 授权等级 \(quote.level) · \(definition.durationDays) 天 · \(kind == .work ? "抽成":"学习比例") \((kind == .work ? definition.commission:1-definition.commission).formatted(.percent.precision(.fractionLength(0))))")
                        .font(.caption).monospacedDigit()
                    Button(model.state.package(kind)?.isActive(at:Date())==true ? "替换套餐…":"签署套餐") { model.signPackage(id:definition.id,level:selectedLevel) }
                        .disabled(!model.packageOperationsEnabled || model.state.level<15 || model.state.money<quote.price)
                } else { Text("此套餐报价超出支持范围，无法签署。").font(.caption).foregroundStyle(.orange) }
            } else { Text("当前目录没有可签署的套餐。").foregroundStyle(.secondary) }
        }.padding(10).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
            .onChange(of:maximum) { _,value in level=min(value,max(15,level)) }
    }
}
