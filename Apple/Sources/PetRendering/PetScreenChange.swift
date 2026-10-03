// SPDX-License-Identifier: Apache-2.0
import Foundation
import CoreGraphics
/// MoveSideHideCheck activates a different physical display only at the edge-check boundary.
public enum PetScreenChange {
    /// Old transient numeric display IDs must be reinitialized from the saved area.
    public static func persistedIdentity(_ raw:String?) -> String? {
        raw.flatMap { UUID(uuidString:$0)?.uuidString }
    }
    public struct Display:Sendable {
        public let id:String
        public let frame:CGRect
        public init(id:String,frame:CGRect) { self.id=id;self.frame=frame }
    }
    private static func valid(_ rect:CGRect) -> Bool {
        [rect.minX,rect.minY,rect.width,rect.height,rect.maxX,rect.maxY].allSatisfy(\.isFinite) && rect.width>0 && rect.height>0
    }
    public static func current(pet:CGRect,displays:[Display]) -> Display? {
        guard valid(pet) else { return nil }
        let intersecting=displays.filter { valid($0.frame) && $0.frame.intersects(pet) }
        guard let selected=intersecting.max(by:{ area($0.frame.intersection(pet))<area($1.frame.intersection(pet)) }),!selected.id.isEmpty else { return nil }
        return selected
    }
    public static func target(enabled:Bool,blocked:Bool,activeID:String?,pet:CGRect,displays:[Display]) -> Display? {
        guard enabled,!blocked,let current=current(pet:pet,displays:displays),current.id != activeID,
              current.frame.width>=pet.width,current.frame.height>=pet.height else { return nil }
        return current
    }
    private static func area(_ rect:CGRect) -> CGFloat { valid(rect) ? rect.width*rect.height:0 }
}
