// SPDX-License-Identifier: Apache-2.0
#if os(macOS)
import AppKit
import PetCore
public enum PetKeyRecording {
    public static func chord(_ event:NSEvent) throws -> PetKeyChord {
        guard event.type == .keyDown,!event.isARepeat else { throw PetKeyboardError.invalidMacro }
        let flags=event.modifierFlags
        let modifiers=PetKeyModifier.allCases.filter { modifier in
            switch modifier {
            case .command:flags.contains(.command)
            case .option:flags.contains(.option)
            case .control:flags.contains(.control)
            case .shift:flags.contains(.shift)
            }
        }
        let names:[UInt16:String]=[36:"Return",48:"Tab",49:"Space",51:"Delete",53:"Escape",76:"Enter",117:"Forward Delete",123:"←",124:"→",125:"↓",126:"↑"]
        let chars=event.charactersIgnoringModifiers ?? ""
        let raw=names[event.keyCode] ?? (chars.isEmpty || chars.unicodeScalars.contains(where:{$0.value<32 || (127...159).contains($0.value) || (0xF700...0xF8FF).contains($0.value)}) ? "Key \(event.keyCode)":chars.uppercased())
        let chord=PetKeyChord(keyCode:Int(event.keyCode),modifiers:modifiers,label:String(raw.prefix(32)))
        try chord.validate();return chord
    }
}
#endif
