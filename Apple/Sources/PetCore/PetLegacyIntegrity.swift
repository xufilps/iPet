// Compatibility with fixed VPet GameSave_v2 hash contracts, not a source-authentication signature.
// SPDX-License-Identifier: Apache-2.0
import Foundation
import CryptoKit

public enum PetLegacyIntegrity {
    public struct Result: Sendable {
        public enum Status: String, Sendable { case verified, mismatch, missing, unsupported }
        public enum Path: String, Sendable { case rootSHA512, rootMD5, legacyPetMD5, none }
        public enum Scope: String, Sendable { case document, pet, none }
        public let status: Status
        public let path: Path
        public let scope: Scope
        public let expected: Int64?
        public let calculated: Int64?
        public let message: String
    }
    public static func inspect(_ document:PetLegacyLPSDocument) -> Result {
        func unsupported(_ message:String) -> Result { Result(status:.unsupported,path:.none,scope:.none,expected:nil,calculated:nil,message:message) }
        func equals(_ left:String,_ right:String) -> Bool { left.utf8.elementsEqual(right.utf8) }
        let pets=document.lines.filter { equals($0.name,"vpet") }
        guard pets.count<=1 else { return unsupported("多个vpet根行，未选择一个进行校验。") }
        if let pet=pets.first {
            let hashes=pet.fields.filter { equals($0.name,"hash") }
            guard hashes.count<=1 else { return unsupported("重复vpet/hash字段，校验路径有歧义。") }
            if let field=hashes.first {
                guard let expected=integer(field.rawInfo) else { return unsupported("vpet/hash不是规范Int64。") }
                var calculated=md5(pet.name) &* 2
                calculated=calculated &+ (md5(pet.rawInfo) &* 3) &+ (md5(pet.rawText) &* 4)
                for field in pet.fields where !equals(field.name,"hash") {
                    calculated=calculated &+ (md5(field.name) &* 2) &+ (md5(field.info) &* 3)
                }
                return result(expected:expected,calculated:calculated,path:.legacyPetMD5,scope:.pet)
            }
        }
        let hashes=document.lines.filter { equals($0.name,"hash") }
        guard hashes.count<=1 else { return unsupported("重复根hash行，校验路径有歧义。") }
        guard let hash=hashes.first else { return Result(status:.missing,path:.none,scope:.none,expected:nil,calculated:nil,message:"未发现原hash，未取得原档完整性校验结果。") }
        guard let expected=integer(hash.rawInfo) else { return unsupported("根hash不是规范Int64。") }
        let versions=hash.fields.filter { equals($0.name,"ver") }
        guard versions.count<=1 else { return unsupported("重复hash/ver字段。") }
        let version:Int64
        if let raw=versions.first?.rawInfo {
            guard let number=integer(raw),Int32(exactly:number) != nil else { return unsupported("hash/ver不是规范Int32。") }
            version=number
        } else { version=0 }
        guard (0...2).contains(version) else { return unsupported("未知hash格式版本\(version)，未猜测算法。") }
        let body=PetLegacyLPSDocument(lines:document.lines.filter { !equals($0.name,"hash") }).canonicalString
        if version != 2 {
            let calculated=md5(body)
            if calculated==expected { return result(expected:expected,calculated:calculated,path:.rootMD5,scope:.document) }
        }
        return result(expected:expected,calculated:sha512(body),path:.rootSHA512,scope:.document)
    }
    private static func integer(_ value:String) -> Int64? {
        guard let number=Int64(value),String(number)==value else { return nil }
        return number
    }
    private static func prefix<D:Sequence>(_ digest:D) -> Int64 where D.Element == UInt8 {
        let bits=digest.prefix(8).enumerated().reduce(UInt64(0)) { $0 | (UInt64($1.element) << ($1.offset*8)) }
        return Int64(bitPattern:bits)
    }
    private static func md5(_ value:String) -> Int64 { prefix(Insecure.MD5.hash(data:Data(value.utf8))) }
    private static func sha512(_ value:String) -> Int64 { prefix(SHA512.hash(data:Data(value.utf8))) }
    private static func result(expected:Int64,calculated:Int64,path:Result.Path,scope:Result.Scope) -> Result {
        let verified=expected==calculated
        let scopeText=scope == .pet ? "仅宠物字段；库存/统计/扩展行及注释未覆盖":"移除hash行后的整档序列化内容"
        let marker=expected == -1 ? "源hash为-1（原版常用未通过标记）；":""
        return Result(status:verified ? .verified:.mismatch,path:path,scope:scope,expected:expected,calculated:calculated,message:marker+(verified ? "原hash匹配，":"原hash不匹配，")+scopeText+"。")
    }
}
