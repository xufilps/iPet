// SPDX-License-Identifier: Apache-2.0
import CoreGraphics
/// MWController.ResetPosition/CheckPosition and RePositionActive, translated to bottom-left coordinates.
public struct PetReposition:Sendable {
    public private(set) var isActive=true
    public init() {}
    public mutating func reset() { isActive=true }
    public mutating func raised(pet:CGRect,area:CGRect,primary:CGRect) {
        isActive = !Self.needsCorrection(pet:pet,area:area,primary:primary)
    }
    public mutating func stop(pet:CGRect,area:CGRect,primary:CGRect) -> CGRect {
        let frame=isActive ? Self.corrected(pet:pet,area:area,primary:primary):pet
        isActive = !Self.needsCorrection(pet:frame,area:area,primary:primary)
        return frame
    }
    private static func valid(_ rect:CGRect) -> Bool {
        [rect.minX,rect.minY,rect.width,rect.height,rect.maxX,rect.maxY].allSatisfy(\.isFinite) && rect.width>0 && rect.height>0
    }
    private static func edges(pet:CGRect,area:CGRect,primary:CGRect) -> (up:Bool,down:Bool,left:Bool,right:Bool)? {
        guard valid(pet),valid(area),valid(primary) else { return nil }
        let up=area.maxY-pet.maxY,down=pet.minY-area.minY,left=pet.minX-area.minX,right=area.maxX-pet.maxX
        return (up < -0.25*pet.height && down < primary.height,
                down < -0.25*pet.height && up < primary.height,
                left < -0.25*pet.width && right < primary.width,
                right < -0.25*pet.width && left < primary.width)
    }
    public static func needsCorrection(pet:CGRect,area:CGRect,primary:CGRect) -> Bool {
        guard let e=edges(pet:pet,area:area,primary:primary) else { return false }
        return e.up || e.down || e.left || e.right
    }
    public static func corrected(pet:CGRect,area:CGRect,primary:CGRect) -> CGRect {
        guard let e=edges(pet:pet,area:area,primary:primary) else { return pet }
        var frame=pet
        if e.up { frame.origin.y=area.maxY-pet.height } else if e.down { frame.origin.y=area.minY }
        if e.left { frame.origin.x=area.minX } else if e.right { frame.origin.x=area.maxX-pet.width }
        return frame
    }
}
