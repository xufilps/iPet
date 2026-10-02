// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetCore
struct DiagnosticsView:View {
    @ObservedObject var model:AppModel
    @State private var description=""
    @State private var includeLogs=false
    @State private var preview=""
    @State private var error=""
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:10) {
                Text("本机诊断与报告").font(.headline)
                Text("当前运行最近200条合并记录；关闭应用后不保留日志。此页面提供原生诊断和本机报告，尚不包含原版完整动画调试控制台。").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("清空内存日志") { model.clearDiagnostics() }
                    Text("\(model.diagnostics.entries.count)条记录").font(.caption)
                }
                ForEach(model.diagnostics.entries.reversed()) { entry in
                    VStack(alignment:.leading,spacing:2) {
                        Text("\(entry.last.formatted(date:.abbreviated,time:.standard)) · \(entry.kind.rawValue) · ×\(entry.count)").font(.caption).foregroundStyle(.secondary)
                        Text(entry.text).font(.caption).textSelection(.enabled)
                    }.padding(6).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:4))
                }
                Divider()
                Text("问题描述（最多10000字）").font(.headline)
                TextEditor(text:$description).frame(height:80)
                Toggle("附加原始内存日志（可能含本机路径）",isOn:$includeLogs)
                Text("默认报告仅包含版本、资源数量、运行状态和事件次数，不附宠物属性、存档、快捷目标或原始日志。导出只生成你预览的文本文件，不自动上传；请自行决定是否分享。").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("刷新报告预览") { refresh() }
                    Button("导出预览报告…") { model.exportDiagnosticReport(preview) }.disabled(preview.isEmpty)
                }
                if !error.isEmpty { Text(error).foregroundStyle(.orange).font(.caption) }
                if preview.isEmpty { Text("描述或日志选项改变后，请刷新预览。").font(.caption).foregroundStyle(.secondary) }
                else { Text(preview).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
            }.padding(16)
        }.onAppear { refresh() }
         .onChange(of:description) { preview="" }
         .onChange(of:includeLogs) { preview="" }
    }
    private func refresh() {
        do { preview=try model.diagnosticReport(description:description,includeLogs:includeLogs);error="" }
        catch { preview="";self.error="报告生成失败：\(error.localizedDescription)" }
    }
}
