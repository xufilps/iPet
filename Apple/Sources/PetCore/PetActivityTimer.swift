// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetActivityTimerMode:Int,CaseIterable,Sendable {
    case elapsed,remaining,earned,compact
    public var next:Self { Self(rawValue:(rawValue+1)%Self.allCases.count)! }
    public var title:String {
        switch self {
        case .elapsed: "已用时间"
        case .remaining: "剩余时间"
        case .earned: "累计收益"
        case .compact: "收起详情"
        }
    }
}
public struct PetActivityTimerReadout:Equatable,Sendable {
    public let value,unit:String
}
/// Display only. All values originate from an existing session, never wall-clock time.
public enum PetActivityTimer {
    public static func readout(feedback:ActivityFeedback,mode:PetActivityTimerMode)->PetActivityTimerReadout? {
        switch mode {
        case .compact: return nil
        case .elapsed: return time(feedback.elapsedSeconds)
        case .remaining:
            guard let remaining=feedback.remainingSeconds else { return PetActivityTimerReadout(value:"—",unit:"时长未知") }
            return time(remaining)
        case .earned:
            return PetActivityTimerReadout(value:format(feedback.earned,precision:2),unit:feedback.unit)
        }
    }
    private static func time(_ seconds:Double)->PetActivityTimerReadout {
        let seconds=seconds.isFinite ? max(0,seconds):0
        let value:Double,unit:String
        if seconds < 90 { value=seconds;unit="秒" }
        else if seconds < 5400 { value=seconds/60;unit="分钟" }
        else { value=seconds/3600;unit="小时" }
        return PetActivityTimerReadout(value:format(value,precision:1),unit:unit)
    }
    private static func format(_ value:Double,precision:Int)->String {
        String(format:"%.\(precision)f",locale:Locale(identifier:"en_US_POSIX"),value)
    }
}
