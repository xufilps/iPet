// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import Foundation

public enum PetSaveError: Error, LocalizedError {
    case unsupportedVersion(Int), unsupportedCatalogVersion(Int), unsupportedInventoryVersion(Int), invalidState, invalidDocument, snapshotTooLarge
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): "存档版本 \(version) 高于本程序支持范围，已停止写入以保护原文件。"
        case .unsupportedCatalogVersion(let version): "玩法目录版本 \(version) 无法识别，已停止写入以保护原文件。"
        case .unsupportedInventoryVersion(let version): "物品参数版本 \(version) 无法识别，已停止写入以保护原文件。"
        case .invalidState: "存档状态数据不合法。"
        case .invalidDocument: "存档格式不正确。"
        case .snapshotTooLarge: "存档超过16MiB，此版本无法导入或导出。"
        }
    }
}
public struct PetSaveDocument: Codable, Equatable, Sendable {
    public let version: Int
    public var state: PetState
    public init(state: PetState) { version = 9; self.state = state }
}
public protocol PetPersistence {
    func load() throws -> PetState?
    func save(_ state: PetState) throws
}
/// Serial filesystem owner. Corruption is preserved; future formats are never overwritten.
public final class PetSaveStore: PetPersistence {
    public let directory: URL
    public var primary: URL { directory.appendingPathComponent("pet.json") }
    public var backup: URL { directory.appendingPathComponent("pet.previous.json") }
    public private(set) var recoveryMessage: String?
    public private(set) var migrationBackupURL: URL?
    public private(set) var lastRestoreBackupURL:URL?
    public static let snapshotSizeLimit=16*1024*1024
    private var pendingLegacy: Data?
    private var preservedLegacy: Set<Data> = []
    private let fm = FileManager.default
    public init(directory: URL) { self.directory = directory }
    private func headerVersion(_ data: Data) throws -> Int {
        struct Header: Decodable { let version: Int }
        return try JSONDecoder().decode(Header.self,from:data).version
    }
    private func decode(_ data: Data) throws -> PetState {
        let version=try headerVersion(data)
        guard version <= 9 else { throw PetSaveError.unsupportedVersion(version) }
        // Inspect nested version markers before decoding their payload. A future record may
        // lack all today's fields; treating it as corruption could otherwise replace its file.
        let root=try JSONSerialization.jsonObject(with:data) as? [String:Any]
        let metadata=(root?["state"] as? [String:Any])?["inventoryMetadata"]
        if let records=metadata as? [String:Any] {
            let future=records.values.compactMap { ($0 as? [String:Any])?["version"] as? Int }.filter { $0>1 }.max()
            if let future { throw PetSaveError.unsupportedInventoryVersion(future) }
        }
        if version<9,metadata != nil,!(metadata is NSNull) { throw PetSaveError.invalidDocument }
        if version == 1 { return try PetSaveMigration.decodeLegacy(data) }
        guard (2...9).contains(version) else { throw PetSaveError.invalidDocument }
        var document=try JSONDecoder().decode(PetSaveDocument.self,from:data)
        guard document.state.catalogVersion <= 1 else { throw PetSaveError.unsupportedCatalogVersion(document.state.catalogVersion) }
        if version<8 {
            guard document.state.growth == nil else { throw PetSaveError.invalidDocument }
            try document.state.migrateDesktopGrowth()
        } else { guard document.state.growth != nil else { throw PetSaveError.invalidDocument } }
        try document.state.validate();return document.state
    }
    private func protected(_ error: Error) -> Bool {
        switch error { case PetSaveError.unsupportedVersion, PetSaveError.unsupportedCatalogVersion, PetSaveError.unsupportedInventoryVersion: true; default: false }
    }
    private func prepareLoaded(_ data: Data) throws -> PetState {
        var state=try decode(data)
        let version=try headerVersion(data)
        if version<9 {
            pendingLegacy=data
            recoveryMessage=(recoveryMessage ?? "")+(version<8 ? "旧累计经验将转换为桌面等级/突破和剩余经验，属性与金币保留；":"旧v8养成与库存数量保持不变；")+"首次写入v9前会独立备份原件。"
        }
        if state.activity != nil { state.activity?.isPaused=true }
        if state.schedule?.isRunning == true { state.schedule?.isPaused=true }
        return state
    }
    private func preserveLegacy(_ data: Data) throws {
        guard !preservedLegacy.contains(data) else { return }
        let version=try headerVersion(data)
        let path=directory.appendingPathComponent("pet.v\(version)-before-upgrade-\(UUID().uuidString).json")
        try data.write(to:path,options:.withoutOverwriting)
        guard try Data(contentsOf:path) == data else { throw PetSaveError.invalidDocument }
        migrationBackupURL=path;preservedLegacy.insert(data)
        recoveryMessage="旧存档原件已保留：\(path.lastPathComponent)"
    }
    public func load() throws -> PetState? {
        recoveryMessage = nil
        if fm.fileExists(atPath: primary.path) {
            let data = try Data(contentsOf: primary) // I/O failure must not be treated as corrupt JSON.
            do { return try prepareLoaded(data) }
            catch where protected(error) { throw error }
            catch {
                let preserved = directory.appendingPathComponent("pet.corrupt-\(UUID().uuidString).json")
                try fm.moveItem(at: primary, to: preserved)
                recoveryMessage = "损坏存档已保留：\(preserved.lastPathComponent)"
            }
        }
        if fm.fileExists(atPath: backup.path) {
            let state = try prepareLoaded(Data(contentsOf: backup))
            recoveryMessage = (recoveryMessage ?? "主存档缺失。") + " 已恢复上一份有效备份。"
            return state
        }
        return nil
    }
    public func exportSnapshot(_ state:PetState) throws -> Data {
        guard state.growth != nil else { throw PetSaveError.invalidState }
        try state.validate()
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        let data=try encoder.encode(PetSaveDocument(state:state))
        guard data.count<=Self.snapshotSizeLimit else { throw PetSaveError.snapshotTooLarge }
        return data
    }
    public func previewImport(_ data:Data) throws -> PetState {
        guard data.count<=Self.snapshotSizeLimit else { throw PetSaveError.snapshotTooLarge }
        var state=try decode(data)
        if state.activity != nil { state.activity?.isPaused=true }
        if state.schedule?.isRunning == true { state.schedule?.isPaused=true }
        return state
    }
    /// The caller obtains explicit confirmation after preview; no running model is changed here.
    public func restore(_ data:Data,currentState:PetState) throws -> PetState {
        let imported=try previewImport(data)
        _=try exportSnapshot(imported) // Compact input may expand when encoded; reject before any filesystem mutation.
        _=try exportSnapshot(currentState)
        try save(currentState) // Protect future primary/backup versions and checkpoint latest memory first.
        let checkpoint=try Data(contentsOf:primary)
        let previous=directory.appendingPathComponent("pet.before-restore-\(UUID().uuidString).json")
        try checkpoint.write(to:previous,options:.withoutOverwriting)
        guard try Data(contentsOf:previous)==checkpoint else { throw PetSaveError.invalidDocument }
        lastRestoreBackupURL=previous
        let source=directory.appendingPathComponent("pet.import-source-\(UUID().uuidString).json")
        try data.write(to:source,options:.withoutOverwriting)
        guard try Data(contentsOf:source)==data else { throw PetSaveError.invalidDocument }
        if try headerVersion(data)<9 { try preserveLegacy(data) }
        try save(imported)
        return imported
    }
    public func save(_ state: PetState) throws {
        // Validate and size-check the complete output before touching primary, backup or originals.
        let encoded=try exportSnapshot(state)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: backup.path) {
            let previous = try Data(contentsOf: backup)
            do { _ = try decode(previous) }
            catch where protected(error) { throw error }
            catch {
                let preserved = directory.appendingPathComponent("pet.previous.corrupt-\(UUID().uuidString).json")
                try fm.moveItem(at: backup, to: preserved)
            }
        }
        if fm.fileExists(atPath: primary.path) {
            let existing = try Data(contentsOf: primary)
            do {
                _ = try decode(existing)
                if try headerVersion(existing) < 9 { try preserveLegacy(existing) }
                if let data=pendingLegacy { try preserveLegacy(data) }
                try existing.write(to: backup, options: .atomic)
            }
            catch where protected(error) { throw error }
            catch let error as CocoaError { throw error }
            catch { throw PetSaveError.invalidDocument } // Require explicit recovery before replacing corrupt data.
        }
        if let data=pendingLegacy { try preserveLegacy(data) }
        try encoded.write(to: primary, options: .atomic)
        pendingLegacy=nil
    }
}
