// SPDX-License-Identifier: Apache-2.0
#if os(macOS)
import AppKit
import Combine
import CoreGraphics
import PetCore

public struct PetKeyboardEventPair {
    public let down:CGEvent
    public let up:CGEvent
    public static func make(_ step:PetKeyboardStep) throws -> Self {
        let code:CGKeyCode
        var flags:CGEventFlags=[]
        var units:[UniChar]=[]
        switch step {
        case .key(let chord):
            try chord.validate();code=CGKeyCode(chord.keyCode)
            for modifier in chord.modifiers {
                switch modifier {
                case .command:flags.insert(.maskCommand)
                case .option:flags.insert(.maskAlternate)
                case .control:flags.insert(.maskControl)
                case .shift:flags.insert(.maskShift)
                }
            }
        case .text(let text):
            try PetKeyboardMacro(steps:[.text(text)]).validate()
            guard text.utf16.count<=20,!text.contains("\n"),!text.contains("\r"),!text.contains("\t") else { throw PetKeyboardError.invalidMacro }
            units=Array(text.utf16);code=0
        }
        guard let down=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:true),
              let up=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:false) else { throw PetKeyboardError.invalidMacro }
        down.flags=flags;up.flags=flags
        if !units.isEmpty {
            units.withUnsafeBufferPointer { buffer in
                down.keyboardSetUnicodeString(stringLength:buffer.count,unicodeString:buffer.baseAddress!)
                up.keyboardSetUnicodeString(stringLength:buffer.count,unicodeString:buffer.baseAddress!)
            }
        }
        return Self(down:down,up:up)
    }
}

@MainActor public final class PetKeyboardSender:ObservableObject {
    @Published public private(set) var busy=false
    @Published public private(set) var status="尚未发送按键。"
    public var onStatus:((String)->Void)?
    private let ownPID:Int32
    private let permission:()->Bool
    private let frontmostPID:()->Int32?
    private let alive:(Int32)->Bool
    private let post:(PetKeyboardEventPair,Int32)->Void
    private let delayNanoseconds:UInt64
    private var task:Task<Void,Never>?
    private var cancelled=false
    private var targetPID:Int32?
    public convenience init() {
        self.init(ownPID:ProcessInfo.processInfo.processIdentifier,
                  permission:{CGPreflightPostEventAccess()},
                  frontmostPID:{NSWorkspace.shared.frontmostApplication?.processIdentifier},
                  alive:{pid in NSRunningApplication(processIdentifier:pid).map { !$0.isTerminated } ?? false},
                  post:{pair,pid in pair.down.postToPid(pid);pair.up.postToPid(pid)})
    }
    // Injected environment makes lifecycle checks testable without requesting access or posting events.
    public init(ownPID:Int32,permission:@escaping ()->Bool,frontmostPID:@escaping ()->Int32?,alive:@escaping (Int32)->Bool,post:@escaping (PetKeyboardEventPair,Int32)->Void,delayNanoseconds:UInt64=30_000_000) {
        self.ownPID=ownPID;self.permission=permission;self.frontmostPID=frontmostPID;self.alive=alive;self.post=post;self.delayNanoseconds=delayNanoseconds
    }
    public var hasPermission:Bool { permission() }
    public func requestPermission() { // Called only by the explicit UI permission button.
        _=CGRequestPostEventAccess()
        report(permission() ? "系统允许发送按键，请切到目标应用后从菜单触发。":"尚未获得发送权限，请检查系统设置的辅助功能授权。")
    }
    private func report(_ text:String) { status=text;onStatus?(text) }
    @discardableResult public func start(_ macro:PetKeyboardMacro,name:String) -> Bool {
        let pid=frontmostPID()
        guard PetKeyboardDeliveryGate.canStart(permission:permission(),frontmostPID:pid.map(Int.init),ownPID:Int(ownPID),busy:busy),let pid,alive(pid) else {
            report(busy ? "已有按键任务，请先停止剩余步骤。":"无法发送：需要权限，且目标应用必须在前台。请切到其它应用后从菜单栏或随宠菜单触发。");return false
        }
        let emissions:[PetKeyboardStep]
        do { emissions=try macro.emissions() }
        catch { report("按键计划无效：\(error.localizedDescription)");return false }
        cancelled=false;busy=true;targetPID=pid
        report("准备向前台应用请求发送：\(name)。")
        task=Task { [weak self] in
            guard let self else { return }
            defer { self.busy=false;self.task=nil;self.targetPID=nil }
            for step in emissions {
                guard PetKeyboardDeliveryGate.canContinue(permission:self.permission(),frontmostPID:self.frontmostPID().map(Int.init),targetPID:Int(pid),targetAlive:self.alive(pid),cancelled:self.cancelled || Task.isCancelled) else {
                    self.report("已取消剩余按键：目标、权限或生命周期发生变化。");return
                }
                do {
                    let pair=try PetKeyboardEventPair.make(step)
                    // No suspension between down and up. Cancellation is checked before each pair.
                    self.post(pair,pid)
                    try await Task.sleep(nanoseconds:self.delayNanoseconds)
                } catch {
                    self.report(Task.isCancelled ? "已取消剩余按键。":"无法构造按键事件：\(error.localizedDescription)");return
                }
            }
            self.report("已向原目标请求发送：\(name)。目标是否执行需自行确认。")
        }
        return true
    }
    public func frontmostApplicationChanged() {
        if busy,frontmostPID() != targetPID { cancel() }
    }
    public func cancel() {
        guard busy else { return };cancelled=true;task?.cancel();report("已取消剩余按键。")
    }
}
#endif
