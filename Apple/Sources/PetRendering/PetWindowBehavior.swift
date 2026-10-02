// SPDX-License-Identifier: Apache-2.0
import Foundation
/// Platform-neutral policy; the macOS owner maps this to NSPanel properties.
public struct PetWindowBehavior:Equatable,Sendable {
    public let topMost:Bool
    public let passThrough:Bool
    public let opacity:Double
    public init(topMost:Bool=true,passThrough:Bool=false,opacity:Double=1) {
        self.topMost=topMost;self.passThrough=passThrough
        self.opacity=opacity.isFinite ? min(1,max(0.05,opacity)):1
    }
    public func ignoresMouse(interacting:Bool,opaque:Bool) -> Bool {
        passThrough || (!interacting && !opaque)
    }
}
