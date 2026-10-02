// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetDiagnosticKind:String,CaseIterable,Sendable { case rendering,save,shortcut,keyboard,lifecycle }
public struct PetDiagnosticEntry:Equatable,Sendable,Identifiable {
    public let id:Int
    public let kind:PetDiagnosticKind
    public let text:String
    public let first:Date
    public var last:Date
    public var count:Int
}
public struct PetDiagnostics:Equatable,Sendable {
    public private(set) var entries:[PetDiagnosticEntry]=[]
    private var nextID=1
    public init() {}
    public mutating func record(_ kind:PetDiagnosticKind,_ text:String,at date:Date) {
        let bounded=String(text.prefix(500))
        if let last=entries.last,last.kind==kind,last.text==bounded {
            entries[entries.count-1].last=date;entries[entries.count-1].count=min(1_000_000_000_000,last.count+1)
        } else {
            entries.append(PetDiagnosticEntry(id:nextID,kind:kind,text:bounded,first:date,last:date,count:1));nextID+=1
            if entries.count>200 { entries.removeFirst(entries.count-200) }
        }
    }
    public mutating func clear() { entries.removeAll() }
}
public struct PetDiagnosticReport:Sendable {
    public let appVersion,systemVersion:String
    public let clips,frames,items:Int
    public let simulationEnabled,visible,writable,saveFailed:Bool
    public init(appVersion:String,systemVersion:String,clips:Int,frames:Int,items:Int,simulationEnabled:Bool,visible:Bool,writable:Bool,saveFailed:Bool) {
        self.appVersion=appVersion;self.systemVersion=systemVersion;self.clips=clips;self.frames=frames;self.items=items
        self.simulationEnabled=simulationEnabled;self.visible=visible;self.writable=writable;self.saveFailed=saveFailed
    }
    public func text(log:PetDiagnostics,description:String,includeLogs:Bool,at date:Date) throws -> String {
        guard description.count<=10000 else { throw PetSaveError.invalidDocument }
        let formatter=ISO8601DateFormatter()
        var lines=["iPet 本机诊断报告","报告时间: "+formatter.string(from:date),"应用版本: "+appVersion,"系统版本: "+systemVersion,
                   "宠物存档 v7 / 快捷配置 v2 / 按键宏 v1","动画组合: \(clips) / 独立帧路径: \(frames) / 物品: \(items)",
                   "养成: \(simulationEnabled) / 显示: \(visible) / 可写: \(writable) / 保存失败: \(saveFailed)",
                   "当前运行内存日志统计（最多200条合并记录，非完整历史）:"]
        for kind in PetDiagnosticKind.allCases { lines.append("\(kind.rawValue): \(log.entries.filter { $0.kind==kind }.reduce(0) { $0+$1.count })") }
        lines += ["","问题描述:",description,"",includeLogs ? "用户选择附加原始内存日志（可能含本机路径）:":"未附原始日志、宠物存档或快捷目标。"]
        if includeLogs {
            for entry in log.entries { lines.append("\(formatter.string(from:entry.first)) — \(formatter.string(from:entry.last)) [\(entry.kind.rawValue)] ×\(entry.count): \(entry.text)") }
        }
        lines.append("本报告仅本机生成，无上传动作。")
        return lines.joined(separator:"\n")+"\n"
    }
}
public extension PetDiagnosticReport {
    static func writePreview(_ text:String,to destination:URL,protectedDirectory:URL) throws {
        let target=destination.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
        let protected=protectedDirectory.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
        guard !text.isEmpty,target != protected,!target.hasPrefix(protected+"/") else { throw PetSaveError.invalidDocument }
        try Data(text.utf8).write(to:destination,options:.atomic)
    }
}
