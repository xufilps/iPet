// SPDX-License-Identifier: Apache-2.0
import Foundation
import CoreGraphics
import PetCore
public struct PetClimbPlan:Sendable {
    public enum Kind:Sendable { case wall,top,fall }
    public let kind:Kind
    public let left,up:Bool
    public var graphID:String { (kind == .wall ? "climb." : kind == .top ? "climb.top." : "fall.")+(left ? "left" : "right") }
    public var distance:Int { kind == .top ? 10:7 }
    public static func make(left:Bool,up:Bool,mood:PetMood,pet:CGRect,screen:CGRect) -> Self? {
        guard mood != .ill,pet.width.isFinite,pet.width>0,!screen.isEmpty,screen.intersects(pet),pet.minY>=screen.minY,pet.maxY<=screen.maxY else { return nil }
        let scale=pet.width/500,side=left ? pet.minX-screen.minX : screen.maxX-pet.maxX
        let vertical=up ? screen.maxY-pet.maxY : pet.minY-screen.minY
        guard side<=100*scale,vertical>=200*scale else { return nil }
        return Self(kind:.wall,left:left,up:up)
    }
    private static func valid(mood:PetMood,pet:CGRect,screen:CGRect) -> Bool {
        mood != .ill && [pet.minX,pet.minY,pet.width,pet.height,screen.minX,screen.minY,screen.width,screen.height].allSatisfy(\.isFinite) && pet.width>0 && pet.height>0 && !screen.isEmpty && screen.intersects(pet)
    }
    public static func makeTop(left:Bool,mood:PetMood,pet:CGRect,screen:CGRect) -> Self? {
        guard valid(mood:mood,pet:pet,screen:screen) else { return nil }
        let scale=pet.width/500,side=left ? pet.minX-screen.minX : screen.maxX-pet.maxX
        guard screen.maxY-pet.maxY<=100*scale,side>=200*scale else { return nil }
        return Self(kind:.top,left:left,up:false)
    }
    public static func makeFall(left:Bool,mood:PetMood,pet:CGRect,screen:CGRect) -> Self? {
        guard valid(mood:mood,pet:pet,screen:screen) else { return nil }
        let scale=pet.width/500,side=left ? pet.minX-screen.minX : screen.maxX-pet.maxX
        guard pet.minY-screen.minY>=200*scale,side>=200*scale else { return nil }
        return Self(kind:.fall,left:left,up:false)
    }
    public func continued(mood:PetMood,pet:CGRect,screen:CGRect) -> Self? {
        switch kind {
        case .wall: return Self.make(left:left,up:up,mood:mood,pet:pet,screen:screen)
        case .top: return Self.makeTop(left:left,mood:mood,pet:pet,screen:screen)
        case .fall: return Self.makeFall(left:left,mood:mood,pet:pet,screen:screen)
        }
    }
    public static func traversalCandidates(mood:PetMood,pet:CGRect,screen:CGRect) -> [Self] {
        candidates(mood:mood,pet:pet,screen:screen)+[true,false].flatMap { left in
            [makeTop(left:left,mood:mood,pet:pet,screen:screen),makeFall(left:left,mood:mood,pet:pet,screen:screen)].compactMap { $0 }
        }
    }
    public static func candidates(mood:PetMood,pet:CGRect,screen:CGRect) -> [Self] {
        [true,false].flatMap { left in [true,false].compactMap { up in make(left:left,up:up,mood:mood,pet:pet,screen:screen) } }
    }
    public func located(pet:CGRect,screen:CGRect) -> CGRect {
        if kind == .fall { return pet }
        if kind == .top { var frame=pet;frame.origin.y=screen.maxY-pet.height+150*pet.width/500;return frame }
        var frame=pet;frame.origin.x=left ? screen.minX-145*pet.width/500 : screen.maxX-185*pet.width/500;return frame
    }
    public func advance(pet:CGRect,screen:CGRect,seconds:Double) -> CGRect? {
        guard seconds.isFinite,seconds>0,seconds<=0.25,Self.valid(mood:.normal,pet:pet,screen:screen) else { return nil }
        if kind != .wall {
            let scale=pet.width/500,side=left ? pet.minX-screen.minX : screen.maxX-pet.maxX
            let horizontal=side-100*scale,vertical=pet.minY-screen.minY-100*scale
            guard horizontal>0,kind != .fall || vertical>0 else { return nil }
            let dx=(kind == .top ? 8.0:14.0)*scale*seconds/0.125,dy=10*scale*seconds/0.125
            let fraction=kind == .fall ? min(1,horizontal/dx,vertical/dy):min(1,horizontal/dx)
            var frame=pet;frame.origin.x+=(left ? -dx:dx)*fraction
            if kind == .fall { frame.origin.y-=dy*fraction }
            return frame
        }
        guard pet.minY>=screen.minY,pet.maxY<=screen.maxY else { return nil }
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
