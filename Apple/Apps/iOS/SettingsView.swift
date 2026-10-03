// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import UIKit

struct IOSSettingsView:View {
    @EnvironmentObject private var model:IOSPetModel
    private let fonts=UIFont.familyNames.sorted().compactMap { UIFont.fontNames(forFamilyName:$0).first }.sorted()
    var body:some View {
        Form {
            Section("本地消息") {
                Toggle("自动消息与饥渴提醒",isOn:$model.automaticDialogue).onChange(of:model.automaticDialogue) { _,_ in model.updateSpeechSettings() }
                Picker("字体",selection:$model.fontFamily) {
                    Text("系统字体").tag("")
                    ForEach(fonts,id:\.self) { Text($0).tag($0) }
                }.onChange(of:model.fontFamily) { _,_ in model.updateSpeechSettings() }
                control("字号",value:$model.fontSize,range:12...24,step:1,suffix:"pt")
                control("透明度",value:$model.opacity,range:0.2...1,step:0.05,suffix:"")
                control("逐字间隔",value:$model.revealInterval,range:0.05...0.5,step:0.05,suffix:"秒")
                control("停留时间倍率",value:$model.holdMultiplier,range:0.5...3,step:0.5,suffix:"倍")
                Text("外观即时生效，播放速度和停留时间从下一条消息生效。预览不改变养成属性。").font(.caption).foregroundStyle(.secondary)
                Button("预览消息") { model.showPreview() }
                if !model.speechText.isEmpty { IOSMessageBubble() }
                Button("恢复消息默认",action:model.resetSpeechSettings)
            }
            Section("本地存档") {
                Text(model.saveError.isEmpty ? "版本9 · 前台每60秒及关键操作后保存；进入后台时保存，后台不补算。":model.saveError)
                Button("立即保存",action:model.save)
                Text("存档保存在本应用沙盒，和macOS存档独立。删除应用可能同时删除本地存档。").font(.caption).foregroundStyle(.secondary)
            }
            Section("关于iPet") {
                Text("iOS / iPadOS 26+ · 固定角色展示\n养成规则和动画来自共享Swift模块。")
                Link("iPet 项目",destination:URL(string:"https://github.com/xufilps/iPet")!)
                Link("原作 VPet",destination:URL(string:"https://github.com/LorisYounger/VPet")!)
                NavigationLink("资源来源与授权") { IOSAttributionView() }
                Text("首版尚无排程/套餐管理/统计明细/旧档导入界面，不包含云存档、联机或多角色。设备性能和长期稳定性仍需真机验证。").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("设置")
    }
    private func control(_ title:String,value:Binding<Double>,range:ClosedRange<Double>,step:Double,suffix:String) -> some View {
        VStack {
            HStack { Text(title);Spacer();Text(value.wrappedValue.formatted(.number.precision(.fractionLength(0...2)))+suffix).foregroundStyle(.secondary) }
            Slider(value:value,in:range,step:step).onChange(of:value.wrappedValue) { _,_ in model.updateSpeechSettings() }
        }
    }
}
private struct IOSAttributionView:View {
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                ForEach(["ATTRIBUTION.md","ANIMATION_LICENSE.md","LICENSE","NOTICE"],id:\.self) { file in
                    VStack(alignment:.leading,spacing:8) {
                        Text(file).font(.headline)
                        Text((Bundle.main.url(forResource:file,withExtension:nil).flatMap { try? String(contentsOf:$0,encoding:.utf8) }) ?? "资源说明不可用，请访问项目仓库。").font(.footnote).textSelection(.enabled)
                    }
                }
            }.padding()
        }.navigationTitle("来源与授权")
    }
}
