// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Offline MessageBar timing; graphemes replace UTF-16 units to keep emoji intact.
public struct PetSpeechPlayback: Sendable {
    public enum Phase: Sendable { case revealing, holding, fading, finished }
    public let fullText: String
    public let wasTruncated: Bool
    public let holdDuration: Double
    private let characters: [Character]
    private let revealInterval:Double
    private var elapsed=0.0
    private var cancelled=false
    private var hovered=false
    private var revealDuration: Double { Double((characters.count+1)/2+1)*revealInterval }
    private var fadeElapsed: Double { max(0,elapsed-revealDuration-holdDuration) }
    public init(text: String,settings:PetSpeechSettings=PetSpeechSettings()) {
        revealInterval=settings.revealInterval
        characters=Array(text.prefix(4000));fullText=String(characters)
        wasTruncated=text.count>4000
        let punctuation=Set<Character>("，。！？；：\n.,!?;:")
        let normalized=fullText.replacingOccurrences(of:"\r",with:"").replacingOccurrences(of:"\n\n",with:"\n")
        holdDuration=(Double(normalized.filter { punctuation.contains($0) }.count)*2+4)*settings.holdMultiplier
    }
    @discardableResult public mutating func advance(by seconds: Double) -> Bool {
        guard !cancelled,seconds.isFinite,seconds>=0 else { return false }
        let wasRevealing=phase == .revealing
        guard !hovered || wasRevealing else { return false }
        // The finite upper bound also avoids overflow on pathological injected clocks.
        elapsed=min(hovered ? revealDuration:revealDuration+holdDuration+2,elapsed+min(seconds,100_000))
        return wasRevealing && phase != .revealing
    }
    public mutating func setHovered(_ value:Bool) {
        guard phase != .finished else { return }
        if value && !hovered && phase == .fading { elapsed=revealDuration+holdDuration }
        hovered=value
    }
    public mutating func cancel() { cancelled=true;hovered=false }
    public var phase: Phase {
        if cancelled || elapsed>=revealDuration+holdDuration+1.95 { return .finished }
        if elapsed<revealDuration { return .revealing }
        return elapsed<revealDuration+holdDuration ? .holding:.fading
    }
    public var displayedText: String {
        guard !cancelled else { return "" }
        let count=min(characters.count,Int((elapsed+1e-9)/revealInterval)*2)
        return String(characters.prefix(count))
    }
    public var opacity: Double {
        guard phase != .finished else { return 0 }
        return max(0.04,0.8-Double(Int((fadeElapsed+1e-9)/0.05))*0.02)
    }
}
