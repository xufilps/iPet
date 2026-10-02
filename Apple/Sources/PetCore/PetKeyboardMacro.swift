// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetKeyboardError:Error,LocalizedError {
    case invalidMacro,unsupportedVersion(Int),tooLarge
    public var errorDescription:String? {
        switch self {
        case .invalidMacro:"按键计划不合法，请检查步骤、录制按键与文本。"
        case .unsupportedVersion(let version):"按键计划版本\(version)无法识别，未执行。"
        case .tooLarge:"按键计划超过32步骤、2048文本UTF16单位或4096配置字限制。"
        }
    }
}
public enum PetKeyModifier:String,Codable,Sendable,CaseIterable { case command,option,control,shift }
public struct PetKeyChord:Codable,Equatable,Sendable {
    public var keyCode:Int
    public var modifiers:[PetKeyModifier]
    public var label:String
    public init(keyCode:Int,modifiers:[PetKeyModifier],label:String) { self.keyCode=keyCode;self.modifiers=modifiers;self.label=label }
    public func validate() throws {
        guard (0...127).contains(keyCode),![54,55,56,57,58,59,60,61,62,63].contains(keyCode),
              modifiers.count<=4,Set(modifiers).count==modifiers.count,
              !label.isEmpty,label.count<=32,!PetUnicodeControls.contains(label) else { throw PetKeyboardError.invalidMacro }
    }
}
public enum PetKeyboardStep:Codable,Equatable,Sendable { case key(PetKeyChord),text(String) }
public struct PetKeyboardMacro:Codable,Equatable,Sendable {
    public let version:Int
    public var steps:[PetKeyboardStep]
    public init(steps:[PetKeyboardStep]) { version=1;self.steps=steps }
    private enum CodingKeys:String,CodingKey { case version,steps }
    public init(from decoder:any Decoder) throws {
        let container=try decoder.container(keyedBy:CodingKeys.self)
        version=try container.decode(Int.self,forKey:.version)
        guard version<=1 else { throw PetKeyboardError.unsupportedVersion(version) }
        steps=try container.decode([PetKeyboardStep].self,forKey:.steps);try validate()
    }
    public func validate() throws {
        guard version==1,!steps.isEmpty else { throw PetKeyboardError.invalidMacro }
        guard steps.count<=32 else { throw PetKeyboardError.tooLarge }
        var units=0
        for step in steps {
            switch step {
            case .key(let chord):try chord.validate()
            case .text(let text):
                guard !text.isEmpty,!PetUnicodeControls.contains(text,allowTextWhitespace:true) else { throw PetKeyboardError.invalidMacro }
                guard text.utf16.count<=2048 else { throw PetKeyboardError.tooLarge }
                units+=text.utf16.count
            }
        }
        guard units<=2048 else { throw PetKeyboardError.tooLarge }
    }
    public func encodedTarget() throws -> String {
        try validate();let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        let target=String(decoding:try encoder.encode(self),as:UTF8.self)
        guard target.count<=4096 else { throw PetKeyboardError.tooLarge };return target
    }
    public static func decodeTarget(_ target:String) throws -> Self {
        guard target.count<=4096 else { throw PetKeyboardError.tooLarge }
        return try JSONDecoder().decode(Self.self,from:Data(target.utf8))
    }
    /// A deterministic posting plan. No platform API, clipboard, or event injection occurs here.
    public func emissions() throws -> [PetKeyboardStep] {
        try validate();var output:[PetKeyboardStep]=[]
        for step in steps {
            switch step {
            case .key:output.append(step)
            case .text(let text):
                let scalars=Array(text.unicodeScalars);var index=0,units=0;var chunk=""
                func flush() { if !chunk.isEmpty { output.append(.text(chunk));chunk="";units=0 } }
                while index<scalars.count {
                    let scalar=scalars[index]
                    if [9,10,13].contains(scalar.value) {
                        flush()
                        let tab=scalar.value==9
                        output.append(.key(PetKeyChord(keyCode:tab ? 48:36,modifiers:[],label:tab ? "Tab":"Return")))
                        if scalar.value==13,index+1<scalars.count,scalars[index+1].value==10 { index+=1 }
                    } else {
                        let count=scalar.value>0xFFFF ? 2:1
                        if units+count>20 { flush() }
                        chunk.unicodeScalars.append(scalar);units+=count
                    }
                    index+=1
                }
                flush()
            }
        }
        return output
    }
}
public enum PetKeyboardDeliveryGate {
    public static func canStart(permission:Bool,frontmostPID:Int?,ownPID:Int,busy:Bool) -> Bool {
        guard permission,!busy,let pid=frontmostPID,pid>0,pid != ownPID else { return false };return true
    }
    public static func canContinue(permission:Bool,frontmostPID:Int?,targetPID:Int,targetAlive:Bool,cancelled:Bool) -> Bool {
        permission && targetPID>0 && frontmostPID==targetPID && targetAlive && !cancelled
    }
}
