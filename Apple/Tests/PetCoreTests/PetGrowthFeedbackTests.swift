// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore

final class PetGrowthFeedbackTests:XCTestCase {
    func testOrdinaryAndBatchGrowthWithNoChangeOrNegativeExperience() throws {
        let before=try PetDesktopGrowth(experience:99)
        XCTAssertNil(PetGrowthFeedback(before:before,after:try PetDesktopGrowth(experience:-1)))
        XCTAssertNil(PetGrowthFeedback(before:before,after:before))
        let feedback=try XCTUnwrap(PetGrowthFeedback(before:before,after:PetDesktopGrowth(level:4)))
        XCTAssertEqual(feedback.levelUps,3);XCTAssertFalse(feedback.didPrestige)
        XCTAssertEqual(feedback.message(name:"萝莉斯"),"萝莉斯升级了：Lv1 → Lv4（共3级）。")
    }
    func testPrestigeAndMultiplePrestigeAreCountedDespiteLowerLevel() throws {
        let single=try XCTUnwrap(PetGrowthFeedback(before:PetDesktopGrowth(level:1000),after:PetDesktopGrowth(level:100,prestige:1)))
        XCTAssertEqual(single.levelUps,1);XCTAssertTrue(single.didPrestige)
        XCTAssertEqual(single.message(name:"萝莉斯"),"萝莉斯等级突破了：0阶 Lv1000 → 1阶 Lv100（共1级）。")
        let next=try XCTUnwrap(PetGrowthFeedback(before:PetDesktopGrowth(level:1100,prestige:1),after:PetDesktopGrowth(level:200,prestige:2)))
        XCTAssertEqual(next.levelUps,1)
        let batch=try XCTUnwrap(PetGrowthFeedback(before:PetDesktopGrowth(level:999),after:PetDesktopGrowth(level:201,prestige:2)))
        XCTAssertEqual(batch.levelUps,1004)
    }
    func testEngineInitialLoadNoReplayAndDrainCoalescesOnce() throws {
        var state=PetState();state.experience=99
        let engine=PetEngine(state:state)
        XCTAssertTrue(engine.drainEvents().isEmpty)
        XCTAssertTrue(engine.applyDialogue(PetDialogueEffects(experience:1)))
        XCTAssertTrue(engine.applySelectionDialogue(PetDialogueEffects(experience:300)))
        let changes=engine.drainEvents().compactMap { if case let .growthChanged(change)=$0 { return change };return nil }
        XCTAssertEqual(changes.count,1);XCTAssertEqual(changes.first?.levelUps,2)
        XCTAssertTrue(engine.drainEvents().isEmpty)
        XCTAssertFalse(engine.applyDialogue(PetDialogueEffects(experience:.infinity)))
        XCTAssertTrue(engine.drainEvents().isEmpty)
        let reopened=PetEngine(state:engine.state);XCTAssertTrue(reopened.drainEvents().isEmpty)
    }
    func testFeedingRetainsExistingItemEvent() throws {
        var state=PetState();state.experience=99
        let item=ItemDefinition(id:"meal",name:"meal",price:1,experience:1)
        let engine=PetEngine(state:state,catalog:PetCatalog(items:[item]))
        XCTAssertTrue(engine.perform(.buyItem("meal",mode:.useImmediately)).accepted)
        let events=engine.drainEvents()
        XCTAssertTrue(events.contains { if case .itemUsed=$0 { return true };return false })
        XCTAssertTrue(events.contains { if case .growthChanged=$0 { return true };return false })
    }
    func testFiniteRejectedTransactionCannotLeakGrowthFeedback() throws {
        var state=PetState();state.growth=try PetDesktopGrowth(experience:99,affectionMax:1e12);state.experience=99
        let engine=PetEngine(state:state),before=engine.state
        XCTAssertFalse(engine.applyDialogue(PetDialogueEffects(strength:10,experience:1)))
        XCTAssertEqual(engine.state,before);XCTAssertTrue(engine.drainEvents().isEmpty)
    }
    func testActivityStopAndGrowthFeedbackCoexist() {
        var state=PetState();state.experience=99
        let work=ActivityDefinition(id:"study",name:"study",graphID:"Study",kind:.study,durationSeconds:60,moneyBase:1,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0)
        let engine=PetEngine(state:state,catalog:PetCatalog(activities:[work]))
        XCTAssertTrue(engine.perform(.startActivity("study")).accepted)
        _=engine.drainEvents()
        XCTAssertTrue(engine.applyDialogue(PetDialogueEffects(experience:1)))
        XCTAssertTrue(engine.perform(.stopActivity).accepted)
        XCTAssertTrue(engine.perform(.schedule(.edit(.appendWait(minutes:1)))).accepted)
        XCTAssertTrue(engine.perform(.schedule(.start)).accepted)
        let events=engine.drainEvents()
        XCTAssertTrue(events.contains { if case .activityStopped=$0 { return true };return false })
        XCTAssertTrue(events.contains { if case .scheduleChanged=$0 { return true };return false })
        XCTAssertTrue(events.contains { if case .growthChanged=$0 { return true };return false })
    }

}
