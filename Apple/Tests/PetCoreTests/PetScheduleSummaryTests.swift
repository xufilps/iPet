// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetScheduleSummaryTests:XCTestCase {
    private func queue(_ entries:String) throws -> PetScheduleQueue {
        try JSONDecoder().decode(PetScheduleQueue.self,from:Data("{\"entries\":[\(entries)],\"nextID\":100}".utf8))
    }
    private func activity(_ id:String,_ kind:ActivityKind,_ minutes:Double) -> ActivityDefinition {
        ActivityDefinition(id:id,name:id,graphID:"test",kind:kind,durationSeconds:minutes*60,levelLimit:0,moneyBase:8,strengthFood:3.5,strengthDrink:2.5,feeling:kind == .play ? -1:1,finishBonus:0.1)
    }
    func testOriginalMixedTotalsAndSeparateEffectiveCycleEstimate() throws {
        let q=try queue(#"{"id":1,"activityID":"work","multiplier":2},{"id":2,"activityID":"study","multiplier":2},{"id":3,"activityID":"play","multiplier":1},{"id":4,"waitMinutes":30,"multiplier":1}"#)
        let catalog=PetCatalog(activities:[activity("work",.work,11),activity("study",.study,7),activity("play",.play,13)])
        let summary=try PetScheduleSummary(queue:q,catalog:catalog)
        // Original base totals: 11+7+floor(13/2)=24, 30+floor(13/2)=36.
        XCTAssertEqual(summary.workMinutes,24);XCTAssertEqual(summary.restMinutes,36)
        XCTAssertEqual(try XCTUnwrap(summary.workFraction),0.4,accuracy:1e-12);XCTAssertFalse(summary.isWorkHeavy)
        // Effective:660 + min600 study +780 +1800 wait +3*30 handoff.
        XCTAssertEqual(summary.cycleSeconds,3930);XCTAssertTrue(summary.unresolvedEntryIDs.isEmpty)
    }
    func testOddPlayMinutesTruncateBeforeBothBuckets() throws {
        let q=try queue(#"{"id":1,"activityID":"play","multiplier":1}"#)
        let summary=try PetScheduleSummary(queue:q,catalog:PetCatalog(activities:[activity("play",.play,11)]))
        XCTAssertEqual(summary.workMinutes,5);XCTAssertEqual(summary.restMinutes,5);XCTAssertEqual(summary.workFraction,0.5)
        XCTAssertEqual(summary.cycleSeconds,690)
    }
    func testSeventyOnePercentWarningIsStrictlyGreater() throws {
        for minutes in [71,72] {
            let q=try queue("{\"id\":1,\"activityID\":\"work\",\"multiplier\":1},{\"id\":2,\"waitMinutes\":\(100-minutes),\"multiplier\":1}")
            let summary=try PetScheduleSummary(queue:q,catalog:PetCatalog(activities:[activity("work",.work,Double(minutes))]))
            XCTAssertEqual(summary.isWorkHeavy,minutes==72)
        }
    }
    func testEmptyAndWaitOnlyHaveHonestRatios() throws {
        let empty=try PetScheduleSummary(queue:PetScheduleQueue(),catalog:PetCatalog())
        XCTAssertEqual(empty.workMinutes,0);XCTAssertEqual(empty.restMinutes,0);XCTAssertNil(empty.workFraction);XCTAssertNil(empty.cycleSeconds)
        let q=try queue(#"{"id":1,"waitMinutes":30,"multiplier":1}"#)
        let wait=try PetScheduleSummary(queue:q,catalog:PetCatalog())
        XCTAssertEqual(wait.workFraction,0);XCTAssertEqual(wait.cycleSeconds,1800);XCTAssertFalse(wait.isWorkHeavy)
    }
    func testUnknownItemsArePreservedAndPartialTotalsAreNotFullRatio() throws {
        let q=try queue(#"{"id":1,"activityID":"missing","multiplier":1},{"id":2,"waitMinutes":30,"multiplier":1}"#),before=q
        let summary=try PetScheduleSummary(queue:q,catalog:PetCatalog())
        XCTAssertEqual(summary.unresolvedEntryIDs,[1]);XCTAssertEqual(summary.restMinutes,30);XCTAssertNil(summary.workFraction);XCTAssertNil(summary.cycleSeconds)
        XCTAssertEqual(q,before)
    }
    func testWaitEditingAndDeletionRefreshDerivedTotals() throws {
        var q=try queue(#"{"id":1,"waitMinutes":30,"multiplier":1}"#)
        XCTAssertTrue(q.edit(.setWait(1,minutes:5),state:PetState(),catalog:PetCatalog(),now:Date()).accepted)
        XCTAssertEqual(try PetScheduleSummary(queue:q,catalog:PetCatalog()).cycleSeconds,300)
        XCTAssertTrue(q.edit(.remove(1),state:PetState(),catalog:PetCatalog(),now:Date()).accepted)
        XCTAssertNil(try PetScheduleSummary(queue:q,catalog:PetCatalog()).cycleSeconds)
    }
    func testInvalidCatalogRejectsAndLargeValidTotalsRemainFinite() throws {
        let q=try queue(#"{"id":1,"activityID":"work","multiplier":1}"#)
        var invalid=activity("work",.work,10);invalid.durationSeconds = -.infinity
        XCTAssertThrowsError(try PetScheduleSummary(queue:q,catalog:PetCatalog(activities:[invalid])))
        var big=activity("work",.work,10);big.durationSeconds=1e12
        let summary=try PetScheduleSummary(queue:q,catalog:PetCatalog(activities:[big]))
        XCTAssertEqual(summary.workMinutes,16_666_666_666);XCTAssertEqual(summary.cycleSeconds,1e12+30)
        XCTAssertEqual(summary.workFraction,1);XCTAssertTrue(summary.isWorkHeavy)
    }
}
