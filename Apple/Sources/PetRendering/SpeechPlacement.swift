// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum SpeechPlacement {
    public static func frame(pet:CGRect,bubble:CGSize,screen:CGRect,preferBelow:Bool=false) -> CGRect {
        let width=min(max(1,bubble.width),screen.width),height=min(max(1,bubble.height),screen.height)
        let above=pet.maxY+8
        let below=pet.minY-height-8
        let y=preferBelow ? (below>=screen.minY ? below : above) : (above+height<=screen.maxY ? above : below)
        return CGRect(x:min(max(pet.midX-width/2,screen.minX),screen.maxX-width),y:min(max(y,screen.minY),screen.maxY-height),width:width,height:height)
    }
}
