// SPDX-License-Identifier: Apache-2.0
public enum PetPointerRelease: Equatable, Sendable { case none, tap, drop }
/// One mouse press owns at most one lift and one release. Coordinates are screen points.
public struct PetPointerGesture: Sendable {
    public private(set) var isPressed=false
    public private(set) var isLifted=false
    private var longPressHandled=false
    private var x=0.0, y=0.0, began=0.0
    public init() {}
    public mutating func begin(x: Double, y: Double, time: Double) {
        cancel();self.x=x;self.y=y;began=time;isPressed=true
    }
    public mutating func move(x: Double, y: Double) -> Bool {
        guard isPressed, !isLifted, (x-self.x)*(x-self.x)+(y-self.y)*(y-self.y) > 16 else { return false }
        isLifted=true;return true
    }
    public mutating func poll(time: Double, canLift: Bool) -> Bool {
        guard isPressed, !isLifted, !longPressHandled, time-began >= 0.3 else { return false }
        longPressHandled=true
        if canLift { isLifted=true;return true }
        return false
    }
    public mutating func release() -> PetPointerRelease {
        let result:PetPointerRelease = !isPressed ? .none : isLifted ? .drop : longPressHandled ? .none : .tap
        cancel();return result
    }
    public mutating func cancel() { isPressed=false;isLifted=false;longPressHandled=false }
}
