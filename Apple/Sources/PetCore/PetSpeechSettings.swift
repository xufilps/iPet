// SPDX-License-Identifier: Apache-2.0
/// Device-local presentation preferences. Never part of the pet save or gameplay rules.
public struct PetSpeechSettings:Equatable,Sendable {
    public let fontFamily:String
    public let fontSize,opacity,revealInterval,holdMultiplier:Double
    public let automaticDialogue:Bool
    public init(fontFamily:String="",fontSize:Double=15,opacity:Double=0.8,revealInterval:Double=0.15,holdMultiplier:Double=1,automaticDialogue:Bool=true) {
        self.fontFamily=fontFamily.count<=200 && !PetUnicodeControls.contains(fontFamily) ? fontFamily:""
        func bounded(_ value:Double,_ range:ClosedRange<Double>,fallback:Double)->Double {
            value.isFinite ? min(range.upperBound,max(range.lowerBound,value)):fallback
        }
        self.fontSize=bounded(fontSize,12...24,fallback:15)
        self.opacity=bounded(opacity,0.2...1,fallback:0.8)
        self.revealInterval=bounded(revealInterval,0.05...0.5,fallback:0.15)
        self.holdMultiplier=bounded(holdMultiplier,0.5...3,fallback:1)
        self.automaticDialogue=automaticDialogue
    }
}
