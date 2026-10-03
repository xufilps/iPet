// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import UIKit
import PetCore

struct IOSMarketView:View {
    @EnvironmentObject private var model:IOSPetModel
    let inventory:Bool
    @State private var search=""
    @State private var selected:ItemDefinition?
    private var items:[ItemDefinition] {
        (inventory ? model.inventoryItems:model.catalog.items).filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.description.localizedCaseInsensitiveContains(search)
        }
    }
    private var unknownIDs:[String] {
        inventory ? model.unknownInventoryIDs.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }:[]
    }
    var body:some View {
        List {
            Section {
                Label("金币 \(model.state.money.formatted(.number.precision(.fractionLength(2))))",systemImage:"creditcard")
                Text(model.message).font(.caption).foregroundStyle(.secondary)
            }
            if items.isEmpty && unknownIDs.isEmpty {
                ContentUnavailableView(inventory && model.state.inventory.isEmpty ? "背包空空的":"没有匹配物品",systemImage:inventory ? "backpack":"magnifyingglass")
            }
            ForEach(unknownIDs,id:\.self) { id in
                VStack(alignment:.leading,spacing:4) {
                    Text("未识别物品：\(id) · 数量 \(model.state.inventory[id,default:0])")
                    Text("数据已保留，当前版本无法使用。").font(.caption).foregroundStyle(.secondary)
                }.textSelection(.enabled)
            }
            ForEach(items) { item in
                Button { selected=item } label: {
                    HStack(spacing:12) {
                        IOSItemImage(item:item,root:model.root).frame(width:52,height:52)
                        VStack(alignment:.leading,spacing:4) {
                            Text(item.name).foregroundStyle(.primary)
                            Text(item.category.title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(inventory ? "×\(model.state.inventory[item.id,default:0])":"\(item.price.formatted(.number.precision(.fractionLength(0...2)))) 金币")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(inventory ? "背包":"商店").searchable(text:$search,prompt:"搜索物品")
        .sheet(item:$selected) { item in
            NavigationStack {
                ScrollView {
                    VStack(alignment:.leading,spacing:20) {
                        IOSItemImage(item:item,root:model.root).frame(width:100,height:100).frame(maxWidth:.infinity)
                        Text(item.description).foregroundStyle(.secondary)
                        Text(item.effectDescription)
                        Text(model.message).font(.callout).foregroundStyle(.secondary)
                        if inventory {
                            Text("库存：\(model.state.inventory[item.id,default:0])")
                            Button("使用一件") { model.perform(.useItem(item.id)) }
                                .buttonStyle(.glassProminent).disabled(!model.canOperate || !model.state.canUseInventory(item.id,catalog:model.catalog))
                        } else {
                            Text("售价：\(item.price.formatted(.number.precision(.fractionLength(0...2)))) 金币")
                            Button("购买并使用") { model.perform(.buyItem(item.id,mode:.useImmediately)) }.buttonStyle(.glassProminent).disabled(!model.canOperate)
                            Button("购买放入背包") { model.perform(.buyItem(item.id,mode:.inventory)) }.buttonStyle(.glass).disabled(!model.canOperate)
                        }
                    }.padding().frame(maxWidth:560)
                }.navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement:.confirmationAction) { Button("完成") { selected=nil } } }
            }.presentationDetents([.medium,.large])
        }
    }
}
struct IOSItemImage:View {
    let item:ItemDefinition
    let root:URL?
    var body:some View {
        if let root,let path=item.imagePath,PetCatalog.safePath(path),let image=UIImage(contentsOfFile:root.appendingPathComponent(path).path) {
            Image(uiImage:image).resizable().scaledToFit().accessibilityLabel(item.name)
        } else { Image(systemName:"shippingbox").resizable().scaledToFit().foregroundStyle(.secondary).accessibilityLabel("\(item.name)，图片不可用") }
    }
}
