// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import Foundation

/// SetMoveMode/SmartMoveTimer: disable autonomous motion after an interaction timeout.
public final class PetSmartMove {
    public static let intervals=[30,60,120,300,600,1200,1800,2400,3000,3600]
    private let clock:any PetClock
    private var previous:TimeInterval?
    private var elapsed=0.0
    private var paused=false
    private var allowMove=true
    private var enabled=false
    public private(set) var interval=1200
    public var isTimedOut:Bool { allowMove && enabled && elapsed>=Double(interval) }
    public var allowsMovement:Bool { allowMove && !paused && !isTimedOut }
    public init(clock:any PetClock=SystemPetClock()) { self.clock=clock }
    public func configure(allowMove:Bool,enabled:Bool,interval:Int) {
        self.allowMove=allowMove;self.enabled=enabled
        self.interval=Self.intervals.contains(interval) ? interval:1200
        elapsed=0;paused=false;resetBaseline()
    }
    public func tick() {
        let now=clock.now
        guard now.isFinite else { previous=nil;return }
        defer { previous=now }
        guard !paused,allowMove,enabled,let previous else { return }
        let delta=now-previous
        guard delta>=0,delta<=30 else { return }
        elapsed=min(Double(interval),elapsed+delta)
    }
    public func interactionEnded(raised:Bool) {
        guard !raised,allowMove,enabled,!paused else { return }
        elapsed=0;resetBaseline()
    }
    public func pause() { tick();paused=true }
    public func resume() { paused=false;resetBaseline() }
    private func resetBaseline() { let now=clock.now;previous=now.isFinite ? now:nil }
}
