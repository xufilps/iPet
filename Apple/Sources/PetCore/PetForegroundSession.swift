// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Single-executor foreground lifecycle. The engine and session must share the same clock.
/// Deactivation settles only the last active slice, then drops the timing baseline.
public final class PetForegroundSession {
    private let engine: PetEngine
    private let clock: any PetClock
    private var previous=0.0
    private var saveSeconds=0.0
    public private(set) var isActive=false
    public init(engine:PetEngine,clock:any PetClock=SystemPetClock()) {
        self.engine=engine;self.clock=clock
    }
    public func activate() {
        guard !isActive else { return }
        isActive=true;previous=clock.now;engine.resetClock()
    }
    public func deactivate() {
        guard isActive else { return }
        _ = tick();isActive=false;engine.resetClock()
    }
    /// True at most once per valid foreground slice; never requests catch-up writes.
    @discardableResult public func tick() -> Bool {
        guard isActive else { return false }
        let now=clock.now,delta=now-previous;previous=now
        engine.tick()
        guard delta.isFinite,delta>=0,delta<=30 else { return false }
        saveSeconds += delta
        guard saveSeconds>=60 else { return false }
        saveSeconds.formTruncatingRemainder(dividingBy:60)
        return true
    }
}
