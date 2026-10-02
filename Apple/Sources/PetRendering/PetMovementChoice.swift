// SPDX-License-Identifier: Apache-2.0
import Foundation
import CoreGraphics
import PetCore
/// One candidate per original move definition, including both directions for wall graphs.
public enum PetMovementChoice:Sendable {
    case walk(PetWalkPlan),traversal(PetClimbPlan)
    public var graphID:String { switch self { case .walk(let p):p.graphID;case .traversal(let p):p.graphID } }
    public var speedX:Double { switch self { case .walk(let p):p.speedX;case .traversal(let p):p.speedX } }
    public var speedY:Double { switch self { case .walk:0;case .traversal(let p):p.speedY } }
    public static func candidates(mood:PetMood,pet:CGRect,screen:CGRect) -> [Self] {
        PetWalkPlan.originalCandidates(mood:mood,pet:pet,screen:screen).map(Self.walk)
        + PetClimbPlan.traversalCandidates(mood:mood,pet:pet,screen:screen).map(Self.traversal)
    }
    public static func score(x:Double,y:Double,nextX:Double,nextY:Double) -> Int {
        func axis(_ a:Double,_ b:Double) -> Int { a == 0 || b == 0 ? 0:(a>0) == (b>0) ? 1:-1 }
        return axis(x,nextX)+axis(y,nextY)
    }
    public func compatible(mood:PetMood,pet:CGRect,screen:CGRect) -> [Self] {
        Self.candidates(mood:mood,pet:pet,screen:screen).filter { Self.score(x:speedX,y:speedY,nextX:$0.speedX,nextY:$0.speedY)>=0 }
    }
}
