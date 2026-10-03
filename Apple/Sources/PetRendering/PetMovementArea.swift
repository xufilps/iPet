// SPDX-License-Identifier: Apache-2.0
import CoreGraphics
public enum PetMovementAreaMode:String,CaseIterable,Sendable { case current,primary,custom }
/// AppKit uses points and a bottom-left origin; supplied screens exclude menu bar/Dock.
public enum PetMovementArea {
    public struct Resolution:Sendable { public let rect:CGRect?;public let adjusted:Bool }
    private static func valid(_ rect:CGRect) -> Bool {
        [rect.origin.x,rect.origin.y,rect.width,rect.height,rect.maxX,rect.maxY].allSatisfy(\.isFinite) && rect.width>0 && rect.height>0
    }
    public static func resolve(mode:PetMovementAreaMode,custom:CGRect?,pet:CGRect,screens:[CGRect]) -> Resolution {
        let physical=screens.filter(valid)
        guard valid(pet),let physicalPrimary=physical.first else { return Resolution(rect:nil,adjusted:true) }
        let physicalCurrent=physical.max { area($0.intersection(pet))<area($1.intersection(pet)) } ?? physicalPrimary
        let usable=physical.filter { $0.width>=pet.width && $0.height>=pet.height }
        guard let primary=usable.first else { return Resolution(rect:nil,adjusted:true) }
        let current=usable.max { area($0.intersection(pet))<area($1.intersection(pet)) } ?? primary
        switch mode {
        case .primary:return Resolution(rect:primary,adjusted:primary != physicalPrimary)
        case .current:return Resolution(rect:current,adjusted:current != physicalCurrent)
        case .custom:
            guard let custom,valid(custom),valid(pet) else { return Resolution(rect:current,adjusted:true) }
            let intersections=usable.map { $0.intersection(custom) }.filter { valid($0) && $0.width>=pet.width && $0.height>=pet.height }
            guard let selected=intersections.max(by:{ area($0)<area($1) }) else { return Resolution(rect:current,adjusted:true) }
            return Resolution(rect:selected,adjusted:selected != custom)
        }
    }
    private static func area(_ rect:CGRect) -> CGFloat { valid(rect) ? rect.width*rect.height:0 }
}
