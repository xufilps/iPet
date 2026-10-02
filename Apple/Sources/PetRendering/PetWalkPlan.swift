// SPDX-License-Identifier: Apache-2.0
import Foundation
import CoreGraphics
import PetCore

/// Bounded horizontal adaptation of vup.lps move speeds and trigger/check distances.
public struct PetWalkPlan:Sendable {
    public let action:PetAction
    public let graphID:String
    public var distance:Int { graphID.hasPrefix("crawl.") ? 8 : graphID.hasSuffix(".faster") || graphID.hasSuffix(".slow") ? 5 : 7 }
    private let speed:Double
    public var speedX:Double { speed }
    public static func make(left:Bool,crawl:Bool,mood:PetMood,pet:CGRect,screen:CGRect) -> Self? {
        guard mood != .ill,pet.width.isFinite,pet.width>0,!screen.isEmpty,screen.contains(pet) else { return nil }
        let trigger=200*pet.width/500
        func room(_ toLeft:Bool) -> CGFloat { toLeft ? pet.minX-screen.minX : screen.maxX-pet.maxX }
        let direction=room(left)>=trigger ? left : !left
        guard room(direction)>=trigger else { return nil }
        let suffix=direction ? "left" : "right"
        let graph=crawl ? "crawl."+suffix : "walk."+suffix+(mood == .happy ? ".faster" : mood == .poor ? ".slow" : "")
        let speed=crawl ? 10.0 : mood == .happy ? 20 : mood == .poor ? 10 : 14
        return Self(action:direction ? .walkLeft : .walkRight,graphID:graph,speed:direction ? -speed : speed)
    }
    public static func originalCandidates(mood:PetMood,pet:CGRect,screen:CGRect) -> [Self] {
        guard mood != .ill,[pet.minX,pet.minY,pet.width,pet.height,screen.minX,screen.minY,screen.width,screen.height].allSatisfy(\.isFinite),pet.width>0,pet.height>0,!screen.isEmpty,screen.intersects(pet) else { return [] }
        return [true,false].flatMap { left -> [Self] in
            let room=left ? pet.minX-screen.minX:screen.maxX-pet.maxX
            guard room>=200*pet.width/500 else { return [] }
            let side=left ? "left":"right",sign=left ? -1.0:1.0
            var choices=[Self(action:left ? .walkLeft:.walkRight,graphID:"crawl."+side,speed:sign*10)]
            if mood == .normal || mood == .poor { choices.append(Self(action:left ? .walkLeft:.walkRight,graphID:"walk."+side,speed:sign*14)) }
            if mood == .happy { choices.append(Self(action:left ? .walkLeft:.walkRight,graphID:"walk."+side+".faster",speed:sign*20)) }
            if mood == .poor { choices.append(Self(action:left ? .walkLeft:.walkRight,graphID:"walk."+side+".slow",speed:sign*10)) }
            return choices
        }
    }
    public func compatible(mood:PetMood,pet:CGRect,screen:CGRect) -> [Self] {
        [false,true].compactMap { crawl in
            guard let plan=Self.make(left:action == .walkLeft,crawl:crawl,mood:mood,pet:pet,screen:screen),plan.action==action else { return nil }
            return plan
        }
    }
    /// Nil ends movement. Does not accumulate suspended time or move outside the screen.
    public func advance(pet:CGRect,screen:CGRect,seconds:Double) -> CGRect? {
        guard seconds.isFinite,seconds>0,seconds<=0.25,pet.width>0,screen.intersects(pet) else { return nil }
        let margin=100*pet.width/500
        let boundary=speed<0 ? screen.minX+margin : screen.maxX-pet.width-margin
        guard speed<0 ? pet.minX>boundary : pet.minX<boundary else { return nil }
        let x=pet.minX+speed*(pet.width/500)*(seconds/0.125)
        var result=pet;result.origin.x=speed<0 ? max(boundary,x) : min(boundary,x)
        return result
    }
}
