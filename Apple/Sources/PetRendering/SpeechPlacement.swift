// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum SpeechPlacement {
    public enum Mode:String,CaseIterable,Sendable { case automatic,inside,outside }
    private static func valid(_ rect:CGRect) -> Bool {
        [rect.minX,rect.minY,rect.width,rect.height,rect.maxX,rect.maxY].allSatisfy(\.isFinite) && rect.width>0 && rect.height>0
    }
    /// Width excludes bubble padding; height reserves the name row, spacing and padding.
    public static func textLimits(pet:CGRect,screen:CGRect,mode:Mode) -> CGSize {
        guard valid(pet),valid(screen) else { return .zero }
        let width=min(240,screen.width-24,mode == .inside ? pet.width-24:240)
        let height=min(400,screen.height-50,mode == .inside ? pet.height-50:400)
        guard width>0,height>0 else { return .zero }
        return CGSize(width:width,height:height)
    }
    public static func frame(pet:CGRect,bubble:CGSize,screen:CGRect,preferBelow:Bool=false,mode:Mode = .automatic) -> CGRect {
        guard valid(pet),valid(screen),bubble.width.isFinite,bubble.height.isFinite,bubble.width>0,bubble.height>0 else { return .zero }
        let width=min(bubble.width,screen.width),height=min(bubble.height,screen.height)
        let above=pet.maxY+8,below=pet.minY-height-8
        let y:CGFloat
        if mode == .inside { y=pet.minY }
        else if mode == .outside || preferBelow { y=below>=screen.minY ? below:above }
        else { y=above+height<=screen.maxY ? above:below }
        return CGRect(x:min(max(pet.midX-width/2,screen.minX),screen.maxX-width),y:min(max(y,screen.minY),screen.maxY-height),width:width,height:height)
    }
}
