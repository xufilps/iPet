// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Original GraphConfig.RaisePoint, measured from the top-left of the logical canvas.
public struct RaiseAnchor: Codable, Sendable {
    public let x, y: Double
    public init(x: Double, y: Double) { self.x=x; self.y=y }
}
public enum PetRaisePlacement {
    /// AppKit screen coordinates point upward; SpriteKit aspect fit may add padding.
    public static func origin(cursor: CGPoint, frame: CGRect, canvas: CGSize, anchor: RaiseAnchor) -> CGPoint? {
        guard [cursor.x,cursor.y,frame.origin.x,frame.origin.y,frame.width,frame.height,canvas.width,canvas.height,anchor.x,anchor.y].allSatisfy(\.isFinite),
              frame.width>0,frame.height>0,canvas.width>0,canvas.height>0,
              (0...canvas.width).contains(anchor.x),(0...canvas.height).contains(anchor.y) else { return nil }
        let scale=min(frame.width/canvas.width,frame.height/canvas.height)
        let insetX=(frame.width-canvas.width*scale)/2, insetY=(frame.height-canvas.height*scale)/2
        let target=CGPoint(x:cursor.x-insetX-anchor.x*scale,y:cursor.y-insetY-(canvas.height-anchor.y)*scale)
        return CGPoint(x:abs(target.x-frame.origin.x)/scale<1 ? frame.origin.x:target.x,
                       y:abs(target.y-frame.origin.y)/scale<1 ? frame.origin.y:target.y)
    }
}
