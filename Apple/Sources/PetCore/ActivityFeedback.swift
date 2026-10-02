// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Read-only presentation of an existing session; never settles rewards or advances time.
public struct ActivityFeedback:Sendable {
    public let title,unit:String
    public let progress:Double?,remainingSeconds:Double?
    public let earned:Double
    public let isPaused,canResume:Bool
    public init(session:ActivitySession,activity:ActivityDefinition?,mood:PetMood) {
        let resolved=activity?.multiplied(by:session.effectiveMultiplier)
        title=resolved?.name ?? "未识别的活动：\(session.activityID)"
        unit=resolved.map { $0.kind == .work ? "金币" : "经验" } ?? "收益（类型未知）"
        earned=session.earned;isPaused=session.isPaused
        canResume=session.isPaused && resolved?.id==session.activityID && mood != .ill
        if let activity=resolved,activity.id==session.activityID,activity.durationSeconds.isFinite,activity.durationSeconds>0 {
            let elapsed=session.elapsedSeconds.isFinite ? max(0,session.elapsedSeconds) : 0
            progress=min(1,elapsed/activity.durationSeconds)
            remainingSeconds=max(0,activity.durationSeconds-elapsed)
        } else { progress=nil;remainingSeconds=nil }
    }
}
