// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetActivityTimerTests:XCTestCase {
    func feedback(elapsed:Double=30,earned:Double=12.5,kind:ActivityKind = .work,known:Bool=true,paused:Bool=false)->ActivityFeedback {
        var session=ActivitySession(activityID:"a");session.elapsedSeconds=elapsed;session.earned=earned;session.isPaused=paused
        let activity=ActivityDefinition(id:"a",name:"活动",graphID:"work",kind:kind,durationSeconds:7200,moneyBase:1,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0)
        return ActivityFeedback(session:session,activity:known ? activity:nil,mood:.normal)
    }
    func testAllFourModesCycleWithoutChangingFeedback() {
        var mode=PetActivityTimerMode.elapsed
        let f=feedback()
        for expected in [PetActivityTimerMode.elapsed,.remaining,.earned,.compact] {
            XCTAssertEqual(mode,expected);mode=mode.next
        }
        XCTAssertEqual(mode,.elapsed)
        XCTAssertEqual(f.elapsedSeconds,30);XCTAssertEqual(f.earned,12.5)
        XCTAssertNil(PetActivityTimer.readout(feedback:f,mode:.compact))
    }
    func testOriginalTimeUnitBoundaries() throws {
        for (seconds,unit) in [(89.9,"秒"),(90.0,"分钟"),(5399.0,"分钟"),(5400.0,"小时")] {
            let r=try XCTUnwrap(PetActivityTimer.readout(feedback:feedback(elapsed:seconds),mode:.elapsed))
            XCTAssertEqual(r.unit,unit)
        }
        XCTAssertEqual(PetActivityTimer.readout(feedback:feedback(elapsed:90),mode:.elapsed)?.value,"1.5")
        XCTAssertEqual(PetActivityTimer.readout(feedback:feedback(elapsed:5400),mode:.elapsed)?.value,"1.5")
    }
    func testPausedUsesSessionTimeAndRemainingClamps() {
        XCTAssertEqual(PetActivityTimer.readout(feedback:feedback(elapsed:30,paused:true),mode:.elapsed)?.value,"30.0")
        XCTAssertEqual(PetActivityTimer.readout(feedback:feedback(elapsed:7201),mode:.remaining)?.value,"0.0")
        XCTAssertEqual(feedback(elapsed:7201).elapsedSeconds,7201)
        XCTAssertEqual(feedback(elapsed:Double.nan).elapsedSeconds,0)
        XCTAssertEqual(feedback(elapsed:-2).elapsedSeconds,0)
    }
    func testUnknownDurationAndKnownEarnedUnits() {
        XCTAssertEqual(PetActivityTimer.readout(feedback:feedback(known:false),mode:.remaining)?.value,"—")
        XCTAssertEqual(PetActivityTimer.readout(feedback:feedback(known:false),mode:.elapsed)?.value,"30.0")
        for kind in ActivityKind.allCases {
            let r=PetActivityTimer.readout(feedback:feedback(kind:kind),mode:.earned)
            XCTAssertEqual(r?.unit,kind == .work ? "金币":"经验")
            XCTAssertEqual(r?.value,"12.50")
        }
    }
}
