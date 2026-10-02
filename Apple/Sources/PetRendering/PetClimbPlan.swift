// SPDX-License-Identifier: Apache-2.0
import Foundation
import CoreGraphics
import PetCore
public struct PetClimbPlan:Sendable {
    public let left,up:Bool
    public var graphID:String { left ? "climb.left" : "climb.right" }
    public var distance:Int { 7 }
    public static func make(left:Bool,up:Bool,mood:PetMood,pet:CGRect,screen:CGRect) -> Self? {
        guard mood != .ill,pet.width.isFinite,pet.width>0,!screen.isEmpty,screen.intersects(pet),pet.minY>=screen.minY,pet.maxY<=screen.maxY else { return nil }
        let scale=pet.width/500,side=left ? pet.minX-screen.minX : screen.maxX-pet.maxX
        let vertical=up ? screen.maxY-pet.maxY : pet.minY-screen.minY
        guard side<=100*scale,vertical>=200*scale else { return nil }
        return Self(left:left,up:up)
    }
    public static func candidates(mood:PetMood,pet:CGRect,screen:CGRect) -> [Self] {
        [true,false].flatMap { left in [true,false].compactMap { up in make(left:left,up:up,mood:mood,pet:pet,screen:screen) } }
    }
    public func located(pet:CGRect,screen:CGRect) -> CGRect {
        var frame=pet;frame.origin.x=left ? screen.minX-145*pet.width/500 : screen.maxX-185*pet.width/500;return frame
    }
    public func advance(pet:CGRect,screen:CGRect,seconds:Double) -> CGRect? {
        guard seconds.isFinite,seconds>0,seconds<=0.25,pet.width>0,screen.intersects(pet),pet.minY>=screen.minY,pet.maxY<=screen.maxY else { return nil }
        let scale=pet.width/500,boundary=up ? screen.maxY-pet.height-100*scale : screen.minY+100*scale
        guard up ? pet.minY<boundary : pet.minY>boundary else { return nil }
        var frame=pet;let y=pet.minY+(up ? 10 : -10)*scale*seconds/0.125
        frame.origin.y=up ? min(boundary,y) : max(boundary,y);return frame
    }
    public static func recovered(pet:CGRect,screen:CGRect) -> CGRect {
        var frame=pet
        frame.origin.x=min(max(pet.minX,screen.minX),max(screen.minX,screen.maxX-pet.width))
        frame.origin.y=min(max(pet.minY,screen.minY),max(screen.minY,screen.maxY-pet.height));return frame
    }
}
