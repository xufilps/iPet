import SwiftUI
import PetCore

struct ControlsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(model.state.name).font(.title2.bold())
                Spacer()
                Text(model.state.resting ? "休息中" : model.state.mood.title).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                metric("体力", model.state.strength)
                metric("饱腹", model.state.food)
                metric("饮水", model.state.drink)
                metric("心情", model.state.feeling)
                metric("健康", model.state.health)
            }
            HStack {
                Button("投喂面包") { model.command(.feed) }
                Button("补充饮料") { model.command(.water) }
                Button(model.state.resting ? "起床" : "休息") { model.command(.toggleRest) }
            }
            Divider()
            HStack {
                Text("桌宠大小")
                Slider(value: $model.size, in: 150...500, step: 10).onChange(of: model.size) { model.updateSize() }
                Text("\(Int(model.size))").monospacedDigit().frame(width: 32)
            }
            Toggle("自主移动", isOn: $model.autoMove).onChange(of: model.autoMove) { model.updateAutoMove() }
            HStack {
                Button(model.visible ? "隐藏桌宠" : "显示桌宠") { model.toggleVisibility() }
                Button("重置位置") { model.resetPosition() }
            }
            Text("点击头部或身体进行抚摸，拖动角色可以提起。右键打开设置；菜单栏 🐾 可找回桌宠。食物与饮料免费提供。").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !model.message.isEmpty { Text(model.message).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
            Divider()
            Text("VPet Apple · v0.1\n角色与动画来自虚拟主播模拟器制作组；原作 LorisYounger/VPet。代码 Apache 2.0，动画和图片适用单独授权。").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Link("原项目与授权", destination: URL(string: "https://github.com/LorisYounger/VPet#动画版权声明与授权")!)
                Button("打开存档目录") { NSWorkspace.shared.open(model.store.directory) }
            }.font(.caption)
        }.padding(22).frame(width: 390)
    }
    private func metric(_ title: String, _ value: Double) -> some View {
        HStack {
            Text(title).frame(width: 34, alignment: .leading)
            ProgressView(value: value, total: 100)
            Text("\(Int(value))").monospacedDigit().frame(width: 30, alignment: .trailing)
        }
    }
}
