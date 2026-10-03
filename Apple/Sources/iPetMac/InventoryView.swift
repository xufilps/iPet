// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore
struct InventoryView: View {
    @ObservedObject var model: AppModel
    @State private var search=""
    @State private var category:ItemCategory?
    @State private var favoritesOnly=false
    @State private var sort:PetInventorySort = .catalog
    @State private var ascending=true
    private var result:PetInventoryResult {
        PetInventoryQuery(search:search,category:category,favoritesOnly:favoritesOnly,sort:sort,ascending:ascending)
            .evaluate(inventory:model.state.inventory,catalog:model.catalog,favorites:model.favoriteItems,metadata:model.state.inventoryMetadata ?? [:])
    }
    var body: some View {
        let inventory=result
        VStack(alignment:.leading,spacing:10) {
            TextField("搜索物品名称",text:$search)
            HStack {
                Picker("分类",selection:$category) {
                    Text("全部").tag(Optional<ItemCategory>.none)
                    ForEach(ItemCategory.allCases,id:\.self) { Text($0.title).tag(Optional($0)) }
                }
                Toggle("只看收藏",isOn:$favoritesOnly)
            }
            HStack {
                Picker("排序",selection:$sort) {
                    ForEach(PetInventorySort.allCases,id:\.self) { Text($0.title).tag($0) }
                }
                Toggle("升序",isOn:$ascending)
            }
            Text("全部库存 \(inventory.totalCount) 件 · 已知物品价值 \(inventory.knownValue.formatted(.number.precision(.fractionLength(2)))) 金币")
                .font(.caption).monospacedDigit()
            if inventory.unpricedCount>0 {
                Text("另有 \(inventory.unpricedCount) 件未知物品未计价，数据仍保留。").font(.caption).foregroundStyle(.secondary)
            }
            if let progress=model.inventoryUseProgress {
                HStack { Text(progress).font(.caption).monospacedDigit();Button("停止剩余使用") { model.cancelInventoryUse() } }
            }
            ScrollView {
                LazyVStack(alignment:.leading,spacing:12) {
                    if inventory.ids.isEmpty {
                        Text(inventory.totalCount == 0 ? "背包还是空的，可以去商店买入物品；买入背包不会立即食用。":"没有符合条件的物品，可以调整搜索或筛选条件。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(inventory.ids,id:\.self) { id in
                        if let item=model.state.inventoryDefinition(id,catalog:model.catalog) {
                            ItemRow(model:model,item:item) {
                                favoriteButton(id:id)
                                InventoryUseControls(model:model,id:id)
                            }
                        } else {
                            HStack {
                                favoriteButton(id:id)
                                Text("未识别物品：\(id) · 数量 \(model.state.inventory[id,default:0])\n数据已保留，当前版本无法使用。").font(.callout).textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }.padding(16)
    }
    private func favoriteButton(id:String) -> some View {
        Button { model.toggleFavorite(id:id) } label: {
            Image(systemName:model.isFavoriteItem(id) ? "star.fill":"star")
        }.accessibilityLabel(model.isFavoriteItem(id) ? "取消收藏":"收藏物品")
    }
}

private struct InventoryUseControls:View {
    @ObservedObject var model:AppModel
    let id:String
    @State private var quantity=1
    private var available:Int { model.state.inventory[id,default:0] }
    var body:some View {
        HStack {
            Text("库存 \(available)").monospacedDigit()
            TextField("数量",value:$quantity,format:.number).frame(width:60).accessibilityLabel("使用数量")
            Stepper("数量",value:$quantity,in:1...max(1,available)).labelsHidden()
            Button("使用所选") { model.useInventory(id:id,count:min(max(1,quantity),available)) }
        }.disabled(model.inventoryUseProgress != nil || !model.state.canUseInventory(id,catalog:model.catalog))
            .onChange(of:available) { _,newValue in quantity=min(max(1,quantity),max(1,newValue)) }
    }
}
