import Foundation

public enum PetSaveError: Error, LocalizedError {
    case unsupportedVersion(Int), invalidState, invalidDocument
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): "存档版本 \(version) 高于本程序支持范围，已停止写入以保护原文件。"
        case .invalidState: "存档状态数据不合法。"
        case .invalidDocument: "存档格式不正确。"
        }
    }
}
public struct PetSaveDocument: Codable, Equatable, Sendable {
    public let version: Int
    public var state: PetState
    public init(state: PetState) { version = 1; self.state = state }
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
    private let fm = FileManager.default
    public init(directory: URL) { self.directory = directory }
    private func decode(_ data: Data) throws -> PetState {
        struct Header: Decodable { let version: Int }
        let header = try JSONDecoder().decode(Header.self, from: data)
        guard header.version <= 1 else { throw PetSaveError.unsupportedVersion(header.version) }
        guard header.version == 1 else { throw PetSaveError.invalidDocument }
        let document = try JSONDecoder().decode(PetSaveDocument.self, from: data)
        try document.state.validate()
        return document.state
    }
    public func load() throws -> PetState? {
        recoveryMessage = nil
        if fm.fileExists(atPath: primary.path) {
            let data = try Data(contentsOf: primary) // I/O failure must not be treated as corrupt JSON.
            do { return try decode(data) }
            catch PetSaveError.unsupportedVersion(let version) { throw PetSaveError.unsupportedVersion(version) }
            catch {
                let preserved = directory.appendingPathComponent("pet.corrupt-\(UUID().uuidString).json")
                try fm.moveItem(at: primary, to: preserved)
                recoveryMessage = "损坏存档已保留：\(preserved.lastPathComponent)"
            }
        }
        if fm.fileExists(atPath: backup.path) {
            let state = try decode(Data(contentsOf: backup))
            recoveryMessage = (recoveryMessage ?? "主存档缺失。") + " 已恢复上一份有效备份。"
            return state
        }
        return nil
    }
    public func save(_ state: PetState) throws {
        try state.validate()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: backup.path) {
            let previous = try Data(contentsOf: backup)
            do { _ = try decode(previous) }
            catch PetSaveError.unsupportedVersion(let version) { throw PetSaveError.unsupportedVersion(version) }
            catch {
                let preserved = directory.appendingPathComponent("pet.previous.corrupt-\(UUID().uuidString).json")
                try fm.moveItem(at: backup, to: preserved)
            }
        }
        if fm.fileExists(atPath: primary.path) {
            let existing = try Data(contentsOf: primary)
            do { _ = try decode(existing); try existing.write(to: backup, options: .atomic) }
            catch PetSaveError.unsupportedVersion(let version) { throw PetSaveError.unsupportedVersion(version) }
            catch let error as CocoaError { throw error }
            catch { throw PetSaveError.invalidDocument } // Require explicit recovery before replacing corrupt data.
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(PetSaveDocument(state: state)).write(to: primary, options: .atomic)
    }
}
