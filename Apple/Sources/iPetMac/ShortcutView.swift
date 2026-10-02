// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetCore
struct ShortcutView:View {
    @ObservedObject var model:AppModel
    @State private var editingID:Int?
    @State private var name=""
    @State private var target=""
    @State private var kind:PetShortcutKind = .url
    var body:some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:14) {
                Text("自定义快捷入口").font(.headline)
                Text("从菜单栏或随宠工具栏打开链接、应用、文件和文件夹。只在你点击时交给系统打开，不运行shell或自动执行；Windows按键、多开和C#插件入口尚未适配。").font(.caption).foregroundStyle(.secondary)
                if !model.shortcutError.isEmpty { Text(model.shortcutError).font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
                if model.shortcuts.entries.isEmpty { Text("尚未添加快捷入口，可在下方创建。").foregroundStyle(.secondary) }
                ForEach(Array(model.shortcuts.entries.enumerated()),id:\.element.id) { index,entry in
                    VStack(alignment:.leading,spacing:6) {
                        HStack {
                            Text(entry.name).font(.headline)
                            Spacer()
                            Button("打开") { model.runShortcut(entry.id) }.disabled(entry.kind == .windowsKeys || entry.kind == .macKeys)
                            Button("编辑") { editingID=entry.id;name=entry.name;target=entry.target;kind=entry.kind }.disabled(!model.shortcutsEditable)
                        }
                        if entry.kind == .macKeys {
                            if let macro=try? PetKeyboardMacro.decodeTarget(entry.target) { Text("原生按键计划 · \(macro.steps.count)步骤").font(.caption).foregroundStyle(.secondary) }
                        } else { Text(entry.target).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(3) }
                        if entry.kind == .macKeys { Text("原生按键配置已识别，录制与发送入口尚在推进，当前不可执行。").font(.caption).foregroundStyle(.secondary) }
                        if entry.kind == .windowsKeys { Text("保留的Windows按键序列，当前不能执行。可删除或编辑为原生链接/路径。").font(.caption).foregroundStyle(.orange) }
                        HStack {
                            Button("置顶") { model.editShortcut(.front(entry.id)) }.disabled(!model.shortcutsEditable || index==0)
                            Button("置底") { model.editShortcut(.back(entry.id)) }.disabled(!model.shortcutsEditable || index==model.shortcuts.entries.count-1)
                            Button("删除") {
                                if model.editShortcut(.remove(entry.id)),editingID==entry.id { clearEditor() }
                            }.disabled(!model.shortcutsEditable)
                        }.controlSize(.small)
                    }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
                }
                Divider()
                Text(editingID==nil ? "添加快捷入口":"编辑快捷入口").font(.headline)
                TextField("名称",text:$name).disabled(!model.shortcutsEditable)
                Picker("目标类型",selection:$kind) {
                    Text("链接").tag(PetShortcutKind.url)
                    Text("应用、文件或文件夹").tag(PetShortcutKind.file)
                    if kind == .windowsKeys { Text("Windows按键（仅保留）").tag(PetShortcutKind.windowsKeys) }
                    if kind == .macKeys { Text("原生按键（发送器待接入）").tag(PetShortcutKind.macKeys) }
                }.disabled(!model.shortcutsEditable)
                if kind == .macKeys {
                    Text("原生按键计划已识别，录制与发送入口尚未开放。可保留当前记录，或改为链接/文件。").font(.caption).foregroundStyle(.secondary)
                } else {
                    TextField(kind == .file ? "绝对路径，例如 /Applications/Safari.app":"完整URL，例如 https://example.com",text:$target).disabled(!model.shortcutsEditable || kind == .windowsKeys)
                }
                if kind == .file { Button("选择应用或文件…") { chooseFile() }.disabled(!model.shortcutsEditable) }
                HStack {
                    Button(editingID==nil ? "添加并保存":"保存修改") {
                        let action:PetShortcutEdit
                        if let id=editingID { action = .update(id,name:name,kind:kind,target:target) }
                        else { action = .add(name:name,kind:kind,target:target) }
                        if model.editShortcut(action) { clearEditor() }
                    }.disabled(!model.shortcutsEditable || name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || target.isEmpty)
                    if editingID != nil { Button("取消编辑") { clearEditor() } }
                }
                Text("保存成功后才更新列表。最多1000项；名称最多100字、目标最多4096字。链接由系统注册的URL处理器打开，未安装或路径失效时报告失败并保留记录；Windows路径与按键不会自动转换。").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("重新读取配置") { model.reloadShortcuts() }
                    Button("恢复上一份快捷备份…") { model.restoreShortcuts() }
                    Button("打开配置目录") { model.openShortcutFolder() }
                }
                Text("快捷入口独立保存在shortcuts.json，不随宠物JSON导出/恢复。损坏或未来版本保留原文件并锁定编辑；恢复备份前独立保留当前原件。").font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
    }
    private func clearEditor() { editingID=nil;name="";target="";kind = .url }
    private func chooseFile() {
        let panel=NSOpenPanel();panel.canChooseFiles=true;panel.canChooseDirectories=true
        panel.allowsMultipleSelection=false;panel.treatsFilePackagesAsDirectories=false
        guard panel.runModal() == .OK,let url=panel.url else { return }
        target=url.path
        if name.isEmpty { name=url.deletingPathExtension().lastPathComponent }
    }
}
