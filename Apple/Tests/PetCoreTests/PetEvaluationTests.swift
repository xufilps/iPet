// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetEvaluationTests:XCTestCase {
    private func date(_ text:String)->Date { ISO8601DateFormatter().date(from:text)! }
    func testSameDayConsecutiveAndGapAcrossYear() {
        var evaluation=PetEvaluation(timeZone:TimeZone(secondsFromGMT:0)!),progress=PetProgress()
        evaluation.begin(progress:&progress,now:date("2025-12-31T12:00:00Z"))
        evaluation.begin(progress:&progress,now:date("2025-12-31T20:00:00Z"))
        XCTAssertEqual(progress.counters?["eval_active_days"],1)
        evaluation.begin(progress:&progress,now:date("2026-01-01T12:00:00Z"))
        XCTAssertEqual(progress.counters?["eval_active_streak"],2)
        evaluation.begin(progress:&progress,now:date("2026-01-03T12:00:00Z"))
        XCTAssertEqual(progress.counters?["eval_active_streak"],1);XCTAssertEqual(progress.counters?["eval_longest_active_streak"],2)
    }
    func testWindowPruningAndMonthsRetainedWithoutReadMutation() {
        var evaluation=PetEvaluation(timeZone:TimeZone(secondsFromGMT:0)!),progress=PetProgress()
        progress.counters=["eval_day_20260101":9,"eval_day_20260102":11,"eval_month_202501":600]
        evaluation.begin(progress:&progress,now:date("2026-02-01T12:00:00Z"))
        evaluation.advance(progress:&progress,now:date("2026-02-01T12:00:00Z"),seconds:15)
        XCTAssertNil(progress.counters?["eval_day_20260101"]);XCTAssertEqual(progress.counters?["eval_day_20260102"],11)
        XCTAssertEqual(progress.counters?["eval_month_202501"],600)
        XCTAssertEqual(progress.counters?["eval_recent_30_days_seconds"],15)
        let before=progress
        let summary=evaluation.summary(progress:progress,now:date("2026-02-03T12:00:00Z"))
        XCTAssertEqual(summary.todaySeconds,0);XCTAssertEqual(summary.recent7Seconds,15);XCTAssertEqual(progress,before)
    }
    func testDSTYesterdayUsesCalendarNotTwentyFourHours() {
        var evaluation=PetEvaluation(timeZone:TimeZone(identifier:"America/Los_Angeles")!),progress=PetProgress()
        evaluation.begin(progress:&progress,now:date("2026-03-08T08:30:00Z"))
        evaluation.advance(progress:&progress,now:date("2026-03-09T07:30:00Z"),seconds:15)
        XCTAssertEqual(progress.counters?["eval_active_streak"],2)
        XCTAssertEqual(progress.counters?["eval_day_20260309"],15)
    }
    func testSessionResetsOnlyAtBeginAndNoHistoryBackfill() {
        var evaluation=PetEvaluation(timeZone:TimeZone(secondsFromGMT:0)!),progress=PetProgress()
        progress.workSeconds=1000
        let now=date("2026-01-01T12:00:00Z")
        evaluation.begin(progress:&progress,now:now);evaluation.advance(progress:&progress,now:now,seconds:15)
        evaluation.advance(progress:&progress,now:now,seconds:15)
        XCTAssertEqual(progress.counters?["eval_longest_session_seconds"],30)
        evaluation.begin(progress:&progress,now:now);evaluation.advance(progress:&progress,now:now,seconds:15)
        XCTAssertEqual(progress.counters?["eval_longest_session_seconds"],30)
        XCTAssertNil(progress.counters?["eval_work_started"])
    }
    func testProjectEncodingRatesPlayGroupingAndEndYield() throws {
        var progress=PetProgress()
        let work=ActivityDefinition(id:"w",name:"中文 A/",graphID:"work",kind:.work,durationSeconds:30,moneyBase:10,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0.5)
        PetEvaluation.started(progress:&progress,work:work)
        PetEvaluation.started(progress:&progress,work:work)
        PetEvaluation.ended(progress:&progress,kind:.work,reason:.completed,earned:20,bonus:10)
        PetEvaluation.ended(progress:&progress,kind:.work,reason:.manual,earned:8,bonus:0)
        XCTAssertEqual(progress.counters?["eval_work_total_money"],38);XCTAssertEqual(progress.counters?["eval_work_completion_rate"],0.5)
        XCTAssertEqual(progress.counters?["eval_work_project_%E4%B8%AD%E6%96%87%20A%2F"],2)
        var play=work;play.kind = .play;PetEvaluation.started(progress:&progress,work:play)
        PetEvaluation.ended(progress:&progress,kind:.play,reason:.completed,earned:5,bonus:2)
        XCTAssertEqual(progress.counters?["eval_study_started"],1);XCTAssertEqual(progress.counters?["eval_study_total_exp"],7)
        var state=PetState();state.progress=progress
        let decoded=try JSONDecoder().decode(PetSaveDocument.self,from:JSONEncoder().encode(PetSaveDocument(state:state)))
        XCTAssertEqual(decoded.state.progress,progress);XCTAssertEqual(decoded.version,8)
    }
    func testRestoredActivityDoesNotCountNewStartAndLongNamesRemainSavable() throws {
        var progress=PetProgress()
        let work=ActivityDefinition(id:"w",name:String(repeating:"中",count:300),graphID:"work",kind:.work,durationSeconds:30,moneyBase:1,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0)
        PetEvaluation.started(progress:&progress,work:work)
        XCTAssertEqual(progress.counters?["eval_work_project_name_untracked"],1)
        try progress.validate()
        var state=PetState();state.progress=progress;state.activity=ActivitySession(activityID:"w")
        let engine=PetEngine(state:state,catalog:PetCatalog(activities:[work]),wallClock:FixedWallClock())
        _=engine.perform(.pauseActivity);_=engine.perform(.resumeActivity)
        XCTAssertEqual(engine.state.progress?.counters?["eval_work_started"],1)
        try engine.state.validate()
    }
    func testEngineStartPauseResumeAndNoOfflineOrDisabledSampling() throws {
        let clock=FakeClock(),wall=FixedWallClock()
        let work=ActivityDefinition(id:"w",name:"工作",graphID:"work",kind:.work,durationSeconds:30,moneyBase:10,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0.5)
        let engine=PetEngine(clock:clock,random:FixedRandom(),catalog:PetCatalog(activities:[work]),wallClock:wall)
        XCTAssertEqual(engine.state.progress?.counters?["eval_active_days"],1)
        _=engine.perform(.startActivity("w"));_=engine.perform(.pauseActivity);_=engine.perform(.resumeActivity)
        XCTAssertEqual(engine.state.progress?.counters?["eval_work_started"],1)
        clock.now=15;engine.tick();clock.now=1000;engine.tick();engine.resetClock();clock.now=1015;engine.tick();clock.now=1016;engine.tick()
        XCTAssertEqual(engine.state.progress?.counters?["eval_longest_session_seconds"],30)
        XCTAssertEqual(engine.state.progress?.counters?["eval_work_completed"],1)
        let record=try XCTUnwrap(engine.state.progress?.history.last)
        XCTAssertEqual(engine.state.progress?.counters?["eval_work_total_money"],record.earned+record.bonus)
        engine.configureSimulation(enabled:false,fixedMood:.normal);clock.now=1031;engine.tick()
        XCTAssertEqual(engine.state.progress?.counters?["eval_longest_session_seconds"],30)
    }
}
