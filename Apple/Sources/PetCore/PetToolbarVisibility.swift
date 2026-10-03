// SPDX-License-Identifier: Apache-2.0
/// Local presentation timing only; never advances pet state or offline time.
public struct PetToolbarVisibility:Sendable {
    private var deadline:Double?
    private var lastTime:Double?
    private var visible=true
    public init() {}
    public mutating func reset() { self=Self() }
    public mutating func update(now:Double,autoHide:Bool,hovered:Bool,menuTracking:Bool)->Bool {
        guard now.isFinite else { return visible }
        if let lastTime,now < lastTime { reset() }
        lastTime=now
        if !autoHide || hovered || menuTracking {
            visible=true;deadline=nil;return true
        }
        if visible {
            if deadline == nil { deadline=now+4 }
            if let deadline,now >= deadline { visible=false }
        }
        return visible
    }
}
