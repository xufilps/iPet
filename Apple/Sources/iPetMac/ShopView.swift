// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetCore
struct ShopView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var category: ItemCategory?
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            TextField("搜索物品或效果",text:$search)
            Picker("分类",selection:$category) {
                Text("全部").tag(Optional<ItemCategory>.none)
                ForEach(ItemCategory.allCases,id:\.self) { Text($0.title).tag(Optional($0)) }
            }
            Text("早期低价物品可赊账；昂贵物品或经验增量达到 1000 的物品，余额须高于价格。重复食用会衰减，下面显示当前效果倍率。").font(.caption).foregroundStyle(.secondary)
            if !model.simulationEnabled {
                Text("养成已关闭：购买即用入口只播放进食动画，不扣款或加属性；买入背包仍按正常价格购买，已有库存使用仍会生效。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(spacing:12) {
                    ForEach(model.catalog.items.filter { (category == nil || $0.category == category) && (search.isEmpty || ($0.name+$0.effectDescription+$0.description).localizedCaseInsensitiveContains(search)) }) { item in
                        ItemRow(model:model,item:item) {
                            Button("买入背包") { model.perform(.buyItem(item.id,mode:.inventory)) }
                            Button(model.simulationEnabled ? "购买并使用":"播放进食动画") { model.perform(.buyItem(item.id,mode:.useImmediately)) }
                        }
                    }
                }
            }
        }.padding(16)
    }
}
struct ItemRow<Actions:View>: View {
    @ObservedObject var model: AppModel
    let item: ItemDefinition
    @ViewBuilder var actions: () -> Actions
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(alignment:.top,spacing:12) {
                if let path=item.imagePath, let image=NSImage(contentsOf:model.assetRoot.appendingPathComponent(path)) {
                    Image(nsImage:image).resizable().scaledToFit().frame(width:48,height:48).accessibilityLabel(item.name)
                } else { Image(systemName:"shippingbox").frame(width:48,height:48) }
                VStack(alignment:.leading,spacing:4) {
                    Text("\(item.name) · \(item.category.title)").font(.headline)
                    Text("\(item.price.formatted(.number.precision(.fractionLength(0...2)))) 金币 · 当前效果 ×\(model.itemMultiplier(id:item.id).formatted(.number.precision(.fractionLength(2))))").font(.caption)
                    Text(item.effectDescription).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if !item.description.isEmpty { Text(item.description).font(.caption).foregroundStyle(.secondary) }
            HStack { actions(); Spacer() }
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
    }
}
