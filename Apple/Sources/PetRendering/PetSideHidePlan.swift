// SPDX-License-Identifier: Apache-2.0
import Foundation
import CoreGraphics
public struct PetSideHidePlan:Sendable {
    public let left:Bool
    public var graphID:String { left ? "sidehide.left" : "sidehide.right" }
    public static func make(pet:CGRect,screen:CGRect) -> Self? {
        guard [pet.minX,pet.minY,pet.width,pet.height,screen.minX,screen.minY,screen.width,screen.height].allSatisfy(\.isFinite),pet.width>0,pet.height>0,!screen.isEmpty,screen.intersects(pet) else { return nil }
        let threshold=50*pet.width/500
        if pet.minX<screen.minX-threshold { return Self(left:true) }
        if pet.maxX>screen.maxX+threshold { return Self(left:false) }
        return nil
    }
    public func located(pet:CGRect,screen:CGRect) -> CGRect {
        var frame=PetClimbPlan.recovered(pet:pet,screen:screen)
        frame.origin.x=left ? screen.minX-219*pet.width/500 : screen.maxX-281*pet.width/500
        return frame
    }
}
