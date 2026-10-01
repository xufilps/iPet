// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import PetCore
struct InventoryView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:12) {
                let ids=model.state.inventory.keys.filter { model.state.inventory[$0,default:0] > 0 }.sorted()
                if ids.isEmpty { Text("背包还是空的，可以先去商店买入物品。怎么购买由你决定，买入背包不会立即食用。").foregroundStyle(.secondary) }
                ForEach(ids,id:\.self) { id in
                    if let item=model.catalog.item(id) {
                        ItemRow(model:model,item:item) {
                            Text("数量 \(model.state.inventory[id,default:0])").monospacedDigit()
                            Button("使用一件") { model.perform(.useItem(id)) }
                        }
                    } else {
                        Text("未识别物品：\(id) · 数量 \(model.state.inventory[id,default:0])\n数据已保留，当前版本无法使用。").font(.callout).textSelection(.enabled)
                    }
                }
            }.padding(16)
        }
    }
}
