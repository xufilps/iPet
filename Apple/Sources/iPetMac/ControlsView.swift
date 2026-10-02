// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetCore

struct ControlsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text(model.state.name).font(.title2.bold())
                Spacer()
                Text("金币 \(model.state.money.formatted(.number.precision(.fractionLength(2))))").monospacedDigit()
                Text(model.simulationEnabled ? (model.state.resting ? "休息中":model.state.mood.title):"固定显示：\(model.presentationMood.title)").foregroundStyle(.secondary)
            }
            TabView(selection:$model.selectedPage) {
                status.tabItem { Text("状态") }.tag(ControlPage.status)
                ActivityView(model:model).tabItem { Text("活动") }.tag(ControlPage.activity)
                ScheduleView(model:model).tabItem { Text("日程") }.tag(ControlPage.schedule)
                ShopView(model:model).tabItem { Text("商店") }.tag(ControlPage.shop)
                InventoryView(model:model).tabItem { Text("背包") }.tag(ControlPage.inventory)
                StatisticsView(model:model).tabItem { Text("统计") }.tag(ControlPage.statistics)
                ShortcutView(model:model).tabItem { Text("快捷") }.tag(ControlPage.shortcuts)
                settings.tabItem { Text("设置") }.tag(ControlPage.settings)
            }
            if !model.message.isEmpty {
                Text(model.message).font(.callout).foregroundStyle(.orange).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
            }
        }.padding(20).frame(minWidth:580,minHeight:520)
    }
    private var status: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("等级 \(model.state.level) · 经验 \(model.state.experience.formatted(.number.precision(.fractionLength(2)))) · 好感 \(model.state.affection.formatted(.number.precision(.fractionLength(1))))")
            metric("体力",model.state.strength); metric("饱腹",model.state.food)
            metric("饮水",model.state.drink); metric("心情",model.state.feeling); metric("健康",model.state.health)
            HStack {
                Button(model.state.resting ? "起床" : "休息") { model.command(.toggleRest) }
                Button("聊一句") { model.sayClick() }.help("本地原版文本可能带少量属性或金币变化，每20秒可聊一次。")
            }
            Text("工作赚取金币，学习与娱乐积累经验。状态会影响活动收益；饥渴或体力不足时先休息、补充食物。生病时可在商店选择药品，免费应急药也会带来属性代价。")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }.padding(16)
    }
    private var settings: some View {
        ScrollView {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("桌宠大小"); Slider(value:$model.size,in:150...500,step:10).onChange(of:model.size) { model.updateSize() }; Text("\(Int(model.size))").monospacedDigit() }
            Toggle("启用养成计算",isOn:$model.simulationEnabled).onChange(of:model.simulationEnabled) { model.updateSimulationSettings() }
            if !model.simulationEnabled {
                Picker("固定显示状态",selection:$model.fixedMood) {
                    ForEach(PetMood.allCases,id:\.self) { Text($0.title).tag($0) }
                }.onChange(of:model.fixedMood) { model.updateSimulationSettings() }
                Text("停止定时养成与当前活动；抚摸只反馈，购买即用只预览。已有库存使用仍消耗并生效，买入背包仍扣款。实际属性保留，开启后恢复判断且不补算。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("窗口置顶",isOn:$model.topMost).onChange(of:model.topMost) { model.updateWindowPreferences() }
            Toggle("角色全部点击穿透",isOn:$model.passThrough).onChange(of:model.passThrough) { model.updateWindowPreferences() }
            HStack {
                Text("角色不透明度")
                Slider(value:$model.opacity,in:0.05...1,step:0.05).onChange(of:model.opacity) { model.updateWindowPreferences() }
                Text(model.opacity.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit().frame(width:45)
            }
            Button("恢复窗口默认设置") { model.resetWindowPreferences() }
            Text("默认只让透明区域穿透。全部穿透时角色不能点击或拖动，可从菜单栏恢复默认；独立工具栏仍可操作，不透明度仅影响角色。")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("随宠工具栏",isOn:$model.toolbarEnabled).onChange(of:model.toolbarEnabled) { model.updateToolbarPreference() }
            Toggle("自主移动",isOn:$model.autoMove).onChange(of:model.autoMove) { model.updateAutoMove() }
            HStack {
                Text("自主互动周期")
                Slider(value:Binding(get:{ Double(model.interactionCycle) },set:{ model.interactionCycle=Int($0.rounded()) }),in:30...1000,step:1)
                    .onChange(of:model.interactionCycle) { model.updateInteractionCycle() }
                Text("\(model.interactionCycle)").monospacedDigit().frame(width:45)
                Button("恢复默认") { model.interactionCycle=200 }
            }
            Text("数值越小通常越活跃；影响随机移动、待机和打盹的机会，不改变养成速度。当前每15秒采样，持续待机后概率会提高，并非固定间隔触发。")
                .font(.caption).foregroundStyle(.secondary)
            HStack { Button(model.visible ? "隐藏桌宠" : "显示桌宠") { model.toggleVisibility() }; Button("重置位置") { model.resetPosition() } }
            Text("点击头部或身体进行抚摸，拖动角色可以提起。右键打开面板；菜单栏 🐾 可找回桌宠或开启随宠工具栏。隐藏后养成继续，退出与系统睡眠期间不补算；重新打开后可在活动页继续暂停的活动。")
                .font(.callout).foregroundStyle(.secondary)
            Divider()
            Text("iPet · v0.2.0\n角色与动画来自虚拟主播模拟器制作组；原作 LorisYounger/VPet。代码 Apache 2.0，动画和图片适用单独授权。原生界面与平台行为仍待实机验收。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Link("原项目与授权",destination:URL(string:"https://github.com/LorisYounger/VPet#动画版权声明与授权")!)
                Button("打开存档目录") { NSWorkspace.shared.open(model.store.directory) }
                Button("导出JSON备份") { model.exportSave() }
                Button("从JSON恢复…") { model.restoreSave() }
            }
            Spacer()
        }.padding(16)
        }
    }
    private func metric(_ title:String,_ value:Double) -> some View {
        HStack { Text(title).frame(width:38,alignment:.leading); ProgressView(value:value,total:100); Text(value.formatted(.number.precision(.fractionLength(1)))).monospacedDigit().frame(width:44,alignment:.trailing) }
    }
}
