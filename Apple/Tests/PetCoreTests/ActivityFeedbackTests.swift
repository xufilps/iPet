import XCTest
@testable import PetCore
final class ActivityFeedbackTests:XCTestCase {
    func testProgressAndRemainingUseActiveElapsedTime() throws {
        let work=ActivityDefinition(id:"work",name:"工作",graphID:"work",kind:.work,durationSeconds:120,moneyBase:1,strengthFood:1,strengthDrink:1,feeling:1,finishBonus:0.5)
        var session=ActivitySession(activityID:"work");session.elapsedSeconds=30;session.earned=12.5
        let feedback=ActivityFeedback(session:session,activity:work,mood:.normal)
        XCTAssertEqual(feedback.progress,0.25);XCTAssertEqual(feedback.remainingSeconds,90)
        XCTAssertEqual(feedback.unit,"金币");XCTAssertEqual(feedback.earned,12.5)
        session.elapsedSeconds=121
        XCTAssertEqual(ActivityFeedback(session:session,activity:work,mood:.normal).progress,1)
        XCTAssertEqual(ActivityFeedback(session:session,activity:work,mood:.normal).remainingSeconds,0)
    }
    func testUnknownOrIllActivityCannotResumeButRetainsFeedback() {
        var session=ActivitySession(activityID:"missing");session.isPaused=true;session.earned=7
        let feedback=ActivityFeedback(session:session,activity:nil,mood:.normal)
        XCTAssertFalse(feedback.canResume);XCTAssertNil(feedback.progress)
        XCTAssertNil(feedback.remainingSeconds);XCTAssertEqual(feedback.earned,7)
        let study=ActivityDefinition(id:"study",name:"学习",graphID:"study",kind:.study,durationSeconds:60,moneyBase:1,strengthFood:1,strengthDrink:1,feeling:1,finishBonus:0)
        session.activityID="study"
        XCTAssertTrue(ActivityFeedback(session:session,activity:study,mood:.normal).canResume)
        XCTAssertFalse(ActivityFeedback(session:session,activity:study,mood:.ill).canResume)
        XCTAssertEqual(ActivityFeedback(session:session,activity:study,mood:.normal).unit,"经验")
    }
}
