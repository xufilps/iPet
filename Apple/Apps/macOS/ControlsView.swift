// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetCore
import PetRendering

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
                conversation.tabItem { Text("对话") }.tag(ControlPage.conversation)
                status.tabItem { Text("状态") }.tag(ControlPage.status)
                ActivityView(model:model).tabItem { Text("活动") }.tag(ControlPage.activity)
                ScheduleView(model:model).tabItem { Text("日程") }.tag(ControlPage.schedule)
                ShopView(model:model).tabItem { Text("商店") }.tag(ControlPage.shop)
                InventoryView(model:model).tabItem { Text("背包") }.tag(ControlPage.inventory)
                StatisticsView(model:model).tabItem { Text("统计") }.tag(ControlPage.statistics)
                ShortcutView(model:model).tabItem { Text("快捷") }.tag(ControlPage.shortcuts)
                DiagnosticsView(model:model).tabItem { Text("诊断") }.tag(ControlPage.diagnostics)
                settings.tabItem { Text("设置") }.tag(ControlPage.settings)
            }
            if !model.message.isEmpty {
                Text(model.message).font(.callout).foregroundStyle(.orange).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
            }
        }.padding(20).frame(minWidth:580,minHeight:520)
    }
    private var status: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("等级 \(model.state.level) · 突破 \(model.state.growth?.prestige ?? 0) · 本级经验 \(model.state.experience.formatted(.number.precision(.fractionLength(2)))) / \((model.state.growth?.nextLevelExperience ?? 100).formatted()) · 好感 \(model.state.affection.formatted(.number.precision(.fractionLength(1)))) / \(model.state.affectionMax.formatted())")
            if !model.growthNotice.isEmpty {
                HStack(alignment:.top) {
                    Text(model.growthNotice).font(.callout).fixedSize(horizontal:false,vertical:true)
                    Spacer()
                    Button("关闭提示") { model.clearGrowthNotice() }
                }
            }
            metric("体力",model.state.strength,total:model.state.strengthMax); metric("饱腹",model.state.food,total:model.state.strengthMax)
            metric("饮水",model.state.drink,total:model.state.strengthMax); metric("心情",model.state.feeling,total:model.state.feelingMax); metric("健康",model.state.health)
            if model.state.strength>model.state.strengthMax || model.state.food>model.state.strengthMax || model.state.drink>model.state.strengthMax || model.state.feeling>model.state.feelingMax {
                Text("突破后已有属性暂时保留，下一次该属性变化时按当前上限调整。").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(model.state.resting ? "起床" : "休息") { model.command(.toggleRest) }
                Button("选话题") { model.showConversation() }
                Button("关闭说话") { model.closeSpeech() }
                Button("聊一句") { model.sayClick() }.help("本地原版文本可能带少量属性或金币变化，每20秒可聊一次。")
            }
            Text("工作赚取金币，学习与娱乐积累经验。状态会影响活动收益；饥渴或体力不足时先休息、补充食物。生病时可在商店选择药品，免费应急药也会带来属性代价。")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }.padding(16)
    }
    private var conversation:some View {
        VStack(alignment:.leading,spacing:12) {
            Text("选择一句想对\(model.state.name)说的话").font(.headline)
            Text("话题按当前状态抽取，选择后可能改变属性或金币，并出现后续话题。每次选择会将原刷新期限延长五分钟。")
                .font(.callout).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment:.leading,spacing:10) {
                    ForEach(model.selectionChoices) { entry in
                        Button { model.selectTopic(entry.id) } label: {
                            VStack(alignment:.leading,spacing:4) {
                                Text(entry.choose).frame(maxWidth:.infinity,alignment:.leading)
                                Text(entry.effectDescription).font(.caption).foregroundStyle(.secondary)
                            }.padding(6)
                        }.disabled(!model.selectionEnabled)
                    }
                    if model.selectionChoices.isEmpty { Text("没有可以说的话，等待下一次刷新。").foregroundStyle(.secondary) }
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
            TimelineView(.periodic(from:.now,by:1)) { _ in
                VStack(alignment:.leading,spacing:8) {
                    ProgressView(value:model.selectionProgress)
                    HStack {
                        Text("下次刷新剩余 \(Int(ceil(model.selectionRemaining))) 秒").monospacedDigit()
                        Spacer()
                        Button("刷新话题") { model.refreshSelection() }.disabled(model.selectionRemaining>0)
                    }
                }
            }
            if !model.lastSelectionEffect.isEmpty { Text("上次效果："+model.lastSelectionEffect).font(.caption) }
            Text("话题池仅保留在本次运行中；重新打开程序会重新抽取。等待时间包含系统睡眠，养成状态不补算。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16).onAppear { model.refreshSelection() }
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
            Picker("说话位置",selection:$model.speechPlacement) {
                Text("自动避让（既有默认）").tag(SpeechPlacement.Mode.automatic)
                Text("角色内，下方对齐").tag(SpeechPlacement.Mode.inside)
                Text("角色外，优先下方").tag(SpeechPlacement.Mode.outside)
            }.onChange(of:model.speechPlacement) { model.updateSpeechPlacement() }
            Text("长文字在气泡中自动滚动；启用气泡交互后也可手动滚动。外置空间不足时改放上方，调整位置不会重新输出或触发文案奖励。")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("说话气泡可交互",isOn:$model.speechInteractive).onChange(of:model.speechInteractive) { model.updateSpeechInteraction() }
            Text("默认气泡点击穿透。开启后悬停保持文字、双击关闭，右键复制已显示文字或关闭；气泡不抢键盘焦点，也可从菜单栏关闭尚未显示的说话。")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("按原版修正超低价商品",isOn:$model.automaticItemPricing).onChange(of:model.automaticItemPricing) { model.updateItemPricing() }
            Text("默认开启，仅修正价格低于原版合理阈值的物品；关闭恢复配置原价，已购库存和历史支出不重算。此开关只控制商品价格。")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("随宠工具栏",isOn:$model.toolbarEnabled).onChange(of:model.toolbarEnabled) { model.updateToolbarPreference() }
            Toggle("工具栏离开后自动隐藏",isOn:$model.toolbarAutoHide).onChange(of:model.toolbarAutoHide) { model.updateToolbarPreference() }
                .disabled(!model.toolbarEnabled)
            Text("开启后离开桌宠和工具栏4秒隐藏；悬停桌宠重新显示，操作菜单时保持显示。默认常驻，自动隐藏不关闭工具栏。")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("自主移动",isOn:$model.autoMove).onChange(of:model.autoMove) { model.updateAutoMove() }
            Toggle("智能移动：长时间未互动后暂停移动",isOn:$model.smartMoveEnabled)
                .disabled(!model.autoMove).onChange(of:model.smartMoveEnabled) { model.updateSmartMoveSettings() }
            Picker("停止移动前的等待时间",selection:$model.smartMoveInterval) {
                ForEach(PetSmartMove.intervals,id:\.self) { seconds in
                    Text(seconds<60 ? "\(seconds) 秒":"\(seconds/60) 分钟").tag(seconds)
                }
            }.disabled(!model.autoMove || !model.smartMoveEnabled)
                .onChange(of:model.smartMoveInterval) { model.updateSmartMoveSettings() }
            Text(model.smartMovePaused ? "移动已因长时间未互动而暂停。轻点角色后恢复；提起放下不会重置计时。":"智能移动只控制移动，不停止养成、待机或说话。默认等待20分钟；睡眠期间暂停计时，松开非提起互动后重新计时。")
                .font(.caption).foregroundStyle(.secondary)
            Picker("移动范围",selection:Binding(get:{ model.movementAreaMode },set:{ model.movementAreaMode=$0;model.updateMovementArea() })) {
                Text("角色所在屏幕（原有默认）").tag(PetMovementAreaMode.current)
                Text("主屏幕").tag(PetMovementAreaMode.primary)
                Text("固定自定义范围").tag(PetMovementAreaMode.custom)
            }
            Toggle("边缘检查时自动切换到角色所在屏幕",isOn:$model.autoChangeScreen).onChange(of:model.autoChangeScreen) { model.updateAutoChangeScreen() }
            Text("仅在跨屏后的提起放下或移动结束检查时更新固定范围；面板或范围选择窗口打开时暂缓。关闭后保留自定义范围，不会移动角色到另一块屏幕。")
                .font(.caption).foregroundStyle(.secondary)
            HStack { Button("检测角色所在屏幕") { model.detectMovementScreen() };Button("自定义范围…") { model.selectMovementArea() } }
            Text("范围使用屏幕可见区域，避开菜单栏与Dock。自定义窗口可拖动缩放；跨屏范围取最大可用交集，不穿过显示器间空隙。")
                .font(.caption).foregroundStyle(.secondary)
            if !model.movementAreaNotice.isEmpty { Text(model.movementAreaNotice).font(.caption).foregroundStyle(.orange) }
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
    private func metric(_ title:String,_ value:Double,total:Double=100) -> some View {
        HStack { Text(title).frame(width:38,alignment:.leading); ProgressView(value:min(value,total),total:total); Text(value.formatted(.number.precision(.fractionLength(1)))+" / "+total.formatted()).monospacedDigit().frame(minWidth:90,alignment:.trailing) }
    }
}
