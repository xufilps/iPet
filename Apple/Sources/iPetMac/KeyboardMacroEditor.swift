// SPDX-License-Identifier: Apache-2.0
import AppKit
import SwiftUI
import PetCore
import PetMacInput

struct KeyboardMacroEditor:View {
    @Binding var steps:[PetKeyboardStep]
    @State private var text=""
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text("按顺序执行组合键与文本；最多32步骤、2048个文本UTF16单位。录制使用当前键盘的物理键码，切换布局后请重新录制。系统快捷键及部分应用对文本事件的处理需实机确认。").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(steps.enumerated()),id:\.offset) { index,step in
                HStack {
                    Text("\(index+1). \(label(step))").lineLimit(2)
                    Spacer()
                    Button("上移") { steps.swapAt(index,index-1) }.disabled(index==0)
                    Button("下移") { steps.swapAt(index,index+1) }.disabled(index==steps.count-1)
                    Button("删除") { steps.remove(at:index) }
                }.controlSize(.small)
            }
            LocalKeyRecorder(enabled:steps.count<32) { chord in steps.append(.key(chord)) }.frame(height:30)
            Text("点击录制按钮后按下组合键，只捕获此控件中的一次按键；点击别处结束录制，不监听其它应用。").font(.caption).foregroundStyle(.secondary)
            TextEditor(text:$text).frame(height:70).overlay(RoundedRectangle(cornerRadius:4).stroke(.quaternary))
            Button("追加文本步骤") { steps.append(.text(text));text="" }.disabled(text.isEmpty || steps.count>=32)
        }
    }
    private func label(_ step:PetKeyboardStep) -> String {
        switch step {
        case .text(let text):return "文本："+text.replacingOccurrences(of:"\n",with:"↵").replacingOccurrences(of:"\t",with:"⇥")
        case .key(let chord):
            let symbols=chord.modifiers.map { modifier in switch modifier { case .command:"⌘";case .option:"⌥";case .control:"⌃";case .shift:"⇧" } }.joined()
            return symbols+chord.label
        }
    }
}
private struct LocalKeyRecorder:NSViewRepresentable {
    let enabled:Bool
    let captured:(PetKeyChord)->Void
    func makeNSView(context:Context) -> RecordingButton {
        let button=RecordingButton();button.bezelStyle = .rounded;button.title="录制一个组合键"
        button.target=button;button.action=#selector(RecordingButton.beginRecording);return button
    }
    func updateNSView(_ button:RecordingButton,context:Context) { button.isEnabled=enabled;button.captured=captured }
}
private final class RecordingButton:NSButton {
    var captured:((PetKeyChord)->Void)?
    private var recording=false
    override var acceptsFirstResponder:Bool { true }
    @objc func beginRecording() { recording=true;title="请按下组合键…";window?.makeFirstResponder(self) }
    override func resignFirstResponder() -> Bool { recording=false;title="录制一个组合键";return super.resignFirstResponder() }
    override func keyDown(with event:NSEvent) {
        guard recording else { super.keyDown(with:event);return }
        guard let chord=try? PetKeyRecording.chord(event) else { return }
        captured?(chord);recording=false;title="录制一个组合键";window?.makeFirstResponder(nil)
    }
    override func performKeyEquivalent(with event:NSEvent) -> Bool {
        // Capture Command shortcuts before the menu responder chain while this control records.
        guard recording,window?.firstResponder === self else { return super.performKeyEquivalent(with:event) }
        keyDown(with:event);return true
    }
}
struct KeyboardDeliveryControls:View {
    @ObservedObject var sender:PetKeyboardSender
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {
                Button("申请系统按键发送权限…") { sender.requestPermission() }
                Button("停止剩余按键") { sender.cancel() }.disabled(!sender.busy)
            }
            Text(sender.status).font(.caption).foregroundStyle(.secondary)
            Text("保存后先切到目标应用，再从菜单栏或随宠工具栏选择该入口；编辑窗口在前台时拒绝发送。更换前台应用、隐藏桌宠、睡眠或退出会取消剩余步骤；已发送内容无法撤回，不使用剪贴板。").font(.caption).foregroundStyle(.secondary)
        }
    }
}
