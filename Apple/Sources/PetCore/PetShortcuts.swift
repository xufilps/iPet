// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetShortcutError:Error,LocalizedError {
    case invalidData,unsupportedVersion(Int),unsupportedTarget,nativeKeysNotReady,tooLarge
    public var errorDescription:String? {
        switch self {
        case .invalidData:"快捷入口数据、名称或目标不合法，原列表未修改。"
        case .unsupportedVersion(let version):"快捷入口版本\(version)无法识别，已保留文件并停止写入。"
        case .nativeKeysNotReady:"原生按键发送器尚未接入，配置已保留。"
        case .unsupportedTarget:"Windows按键序列尚未适配macOS，记录仍保留。"
        case .tooLarge:"快捷入口文件超过16MiB，已停止处理。"
        }
    }
}
public enum PetShortcutKind:String,Codable,Sendable { case url,file,windowsKeys,macKeys }
public struct PetShortcutEntry:Codable,Equatable,Sendable,Identifiable {
    public let id:Int
    public var name:String
    public var kind:PetShortcutKind
    public var target:String
    public init(id:Int,name:String,kind:PetShortcutKind,target:String) { self.id=id;self.name=name;self.kind=kind;self.target=target }
    public func validate() throws {
        guard (1...1_000_000_000_000).contains(id),!name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,name.count<=100,
              !PetUnicodeControls.contains(name),!target.isEmpty,target.count<=4096,
              !PetUnicodeControls.contains(target) else { throw PetShortcutError.invalidData }
        if kind == .macKeys { _=try PetKeyboardMacro.decodeTarget(target) }
        else if kind != .windowsKeys { _=try resolvedURL() }
    }
    /// Returns an explicit system-open target, never a shell command or synthetic keystroke.
    public func resolvedURL() throws -> URL {
        switch kind {
        case .macKeys:throw PetShortcutError.nativeKeysNotReady
        case .windowsKeys:throw PetShortcutError.unsupportedTarget
        case .file:
            guard target.hasPrefix("/"),!PetUnicodeControls.contains(target) else { throw PetShortcutError.invalidData }
            return URL(fileURLWithPath:target)
        case .url:
            guard target==target.trimmingCharacters(in:.whitespacesAndNewlines),!PetUnicodeControls.contains(target),
                  let components=URLComponents(string:target),let scheme=components.scheme?.lowercased(),!scheme.isEmpty,
                  !["file","data","javascript"].contains(scheme),target.count>scheme.count+1,
                  let url=components.url else { throw PetShortcutError.invalidData }
            if ["http","https"].contains(scheme),components.host?.isEmpty != false { throw PetShortcutError.invalidData }
            return url
        }
    }
}
public enum PetShortcutEdit:Sendable {
    case add(name:String,kind:PetShortcutKind,target:String)
    case update(Int,name:String,kind:PetShortcutKind,target:String)
    case remove(Int),front(Int),back(Int)
}
public struct PetShortcutList:Codable,Equatable,Sendable {
    public let version:Int
    public private(set) var entries:[PetShortcutEntry]=[]
    public private(set) var nextID=1
    public init() { version=2 }
    private enum CodingKeys:String,CodingKey { case version,entries,nextID }
    public init(from decoder:any Decoder) throws {
        let container=try decoder.container(keyedBy:CodingKeys.self)
        let sourceVersion=try container.decode(Int.self,forKey:.version)
        guard sourceVersion<=2 else { throw PetShortcutError.unsupportedVersion(sourceVersion) }
        guard (1...2).contains(sourceVersion) else { throw PetShortcutError.invalidData }
        version=2
        entries=try container.decode([PetShortcutEntry].self,forKey:.entries);nextID=try container.decode(Int.self,forKey:.nextID)
        guard sourceVersion != 1 || !entries.contains(where:{ $0.kind == .macKeys }) else { throw PetShortcutError.invalidData }
        try validate()
    }
    public func validate() throws {
        guard version==2,entries.count<=1000,(1...1_000_000_000_001).contains(nextID),
              Set(entries.map(\.id)).count==entries.count,entries.allSatisfy({ $0.id<nextID }) else { throw PetShortcutError.invalidData }
        for entry in entries { try entry.validate() }
    }
    public mutating func edit(_ command:PetShortcutEdit) throws {
        try validate();var next=self
        switch command {
        case .add(let name,let kind,let target):
            guard entries.count<1000,nextID<=1_000_000_000_000 else { throw PetShortcutError.invalidData }
            next.entries.append(PetShortcutEntry(id:nextID,name:name,kind:kind,target:target));next.nextID+=1
        case .update(let id,let name,let kind,let target):
            guard let index=next.entries.firstIndex(where:{ $0.id==id }) else { throw PetShortcutError.invalidData }
            next.entries[index]=PetShortcutEntry(id:id,name:name,kind:kind,target:target)
        case .remove(let id):
            guard let index=next.entries.firstIndex(where:{ $0.id==id }) else { throw PetShortcutError.invalidData }
            next.entries.remove(at:index)
        case .front(let id),.back(let id):
            guard let index=next.entries.firstIndex(where:{ $0.id==id }) else { throw PetShortcutError.invalidData }
            let entry=next.entries.remove(at:index)
            if case .front=command { next.entries.insert(entry,at:0) } else { next.entries.append(entry) }
        }
        try next.validate();self=next
    }
}
/// Separate local configuration: never included in pet state/import or used to alter cultivation.
public final class PetShortcutStore {
    public let directory:URL
    public var primary:URL { directory.appendingPathComponent("shortcuts.json") }
    public var backup:URL { directory.appendingPathComponent("shortcuts.previous.json") }
    public private(set) var recoveryOriginal:URL?
    public private(set) var migrationOriginal:URL?
    private var migrated:Set<Data>=[]
    private let fm=FileManager.default
    public init(directory:URL) { self.directory=directory }
    private func read(_ url:URL) throws -> Data {
        if let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize,size>PetSaveStore.snapshotSizeLimit { throw PetShortcutError.tooLarge }
        let data=try Data(contentsOf:url)
        guard data.count<=PetSaveStore.snapshotSizeLimit else { throw PetShortcutError.tooLarge }
        return data
    }
    private func encode(_ list:PetShortcutList) throws -> Data {
        try list.validate();let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        let data=try encoder.encode(list)
        guard data.count<=PetSaveStore.snapshotSizeLimit else { throw PetShortcutError.tooLarge };return data
    }
    private func decode(_ data:Data) throws -> PetShortcutList { try JSONDecoder().decode(PetShortcutList.self,from:data) }
    private func preserve(_ data:Data,label:String) throws -> URL {
        let path=directory.appendingPathComponent("shortcuts.\(label)-\(UUID().uuidString).json")
        try data.write(to:path,options:.withoutOverwriting)
        guard try read(path)==data else { throw PetShortcutError.invalidData };return path
    }
    private func isFuture(_ error:Error) -> Bool {
        switch error {
        case PetShortcutError.unsupportedVersion,PetKeyboardError.unsupportedVersion:return true
        default:return false
        }
    }
    private func preserveLegacy(_ data:Data) throws {
        struct Header:Decodable { let version:Int }
        guard try JSONDecoder().decode(Header.self,from:data).version==1,!migrated.contains(data) else { return }
        migrationOriginal=try preserve(data,label:"v1-before-upgrade");migrated.insert(data)
    }
    public func load() throws -> PetShortcutList {
        guard fm.fileExists(atPath:primary.path) else { return PetShortcutList() }
        return try decode(read(primary)) // Preserve invalid or future data until explicit recovery.
    }
    public func save(_ list:PetShortcutList) throws {
        let encoded=try encode(list)
        try fm.createDirectory(at:directory,withIntermediateDirectories:true)
        if fm.fileExists(atPath:backup.path) {
            let data=try read(backup)
            do { _=try decode(data) }
            catch where isFuture(error) { throw error }
            catch { _=try preserve(data,label:"previous-corrupt") }
        }
        if fm.fileExists(atPath:primary.path) {
            let old=try read(primary);_=try decode(old) // Any invalid primary blocks overwrite.
            try preserveLegacy(old)
            try old.write(to:backup,options:.atomic)
        }
        try encoded.write(to:primary,options:.atomic)
    }
    public func restoreBackup() throws -> PetShortcutList {
        let source=try read(backup);let selected=try decode(source)
        if fm.fileExists(atPath:primary.path) {
            let current=try read(primary)
            do { _=try decode(current) }
            catch where isFuture(error) { throw error }
            catch {} // Explicit user recovery may replace invalid data after preserving bytes.
            recoveryOriginal=try preserve(current,label:"before-restore")
        }
        try preserveLegacy(source)
        try encode(selected).write(to:primary,options:.atomic)
        return selected
    }
}
