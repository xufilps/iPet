import XCTest
@testable import PetCore
final class PetSelectionDialogueTests:XCTestCase {
    func entry(_ id:String,_ choose:String?=nil,bounds:[String:Double]=[:],tags:[String]=[],to:[String]=[],effects:PetDialogueEffects=PetDialogueEffects()) -> PetSelectionEntry {
        PetSelectionEntry(id:id,choose:choose ?? id,text:"金币{money}",characterTags:["all"],conversationTags:tags,toTags:to,bounds:bounds,effects:effects)
    }
    func session(_ entries:[PetSelectionEntry],clock:FixedWallClock) throws -> PetSelectionSession {
        try PetSelectionSession(catalog:PetSelectionCatalog(version:1,tags:["all"],entries:entries),clock:clock,random:FixedRandom())
    }
    func testBuiltInCatalogAndInclusiveBoundsWithoutWorkMoodFilter() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets/selection-dialogue.json")
        XCTAssertEqual(try PetSelectionCatalog.load(from:root).entries.count,189)
        let e=entry("one",bounds:["healthmin":10,"healthmax":10,"moneymin":-10])
        var s=PetState();s.health=10;s.money = -10;s.resting=true
        XCTAssertTrue(e.matches(state:s));s.health=10.001;XCTAssertFalse(e.matches(state:s))
        s.health=10;s.money = -10.001;XCTAssertFalse(e.matches(state:s))
    }
    func testUniqueFivePoolAndStrictTenMinuteRefresh() throws {
        let c=FixedWallClock(),d=try session([entry("a","same"),entry("b","same")]+(0..<8).map {entry("n\($0)")},clock:c)
        d.refresh(state:PetState());XCTAssertEqual(d.choices.count,5);XCTAssertEqual(Set(d.choices.map(\.choose)).count,5)
        let ids=d.choices.map(\.id),deadline=try XCTUnwrap(d.deadline)
        c.now=deadline;d.refresh(state:PetState());XCTAssertEqual(d.deadline,deadline);XCTAssertEqual(d.choices.map(\.id),ids)
        c.now=deadline.addingTimeInterval(0.001);d.refresh(state:PetState());XCTAssertEqual(d.deadline,c.now.addingTimeInterval(600))
    }
    func testTransactionalChoicePostEffectFollowupAndNoRepeat() throws {
        let c=FixedWallClock(),e=entry("first",to:["next"],effects:PetDialogueEffects(money:2))
        let d=try session([e,entry("follow",bounds:["moneymin":102],tags:["next"]),entry("case",bounds:["moneymin":102],tags:["Next"])],clock:c)
        let engine=PetEngine(clock:FakeClock(),wallClock:c);d.refresh(state:engine.state)
        XCTAssertEqual(d.choices.map(\.id),["first"]);let deadline=try XCTUnwrap(d.deadline)
        XCTAssertNil(d.select(id:"first") { _ in nil });XCTAssertEqual(d.choices.map(\.id),["first"]);XCTAssertEqual(d.deadline,deadline)
        c.now=c.now.addingTimeInterval(100)
        let chosen=d.select(id:"first") { effects in engine.applySelectionDialogue(effects) ? engine.state:nil }
        XCTAssertEqual(chosen?.rendered(state:engine.state),"金币102")
        XCTAssertEqual(d.deadline,deadline.addingTimeInterval(300));XCTAssertEqual(d.choices.map(\.id),["follow"])
        XCTAssertNil(d.select(id:"first") { _ in XCTFail("Repeated choice applied");return engine.state })
        XCTAssertEqual(engine.state.progress?.counters?["stat_say_money_p"],1)
    }
    func testExistingPoolDoesNotRecheckBoundsAndEmptyPoolDoesNotRefillEarly() throws {
        let c=FixedWallClock(),d=try session([entry("first",bounds:["foodmin":50])],clock:c)
        var state=PetState();d.refresh(state:state);state.food=0
        XCTAssertNotNil(d.select(id:"first") { _ in state });d.refresh(state:state);XCTAssertTrue(d.choices.isEmpty)
        c.now=c.now.addingTimeInterval(901);state.food=80;d.refresh(state:state);XCTAssertEqual(d.choices.count,1)
    }
    func testEffectsStatisticsAndInvalidTransactionRollback() throws {
        var s=PetState();s.resting=true;s.strength=80
        let e=PetEngine(state:s,clock:FakeClock(),wallClock:FixedWallClock())
        XCTAssertTrue(e.applySelectionDialogue(PetDialogueEffects(money:-2,strength:10,affection:2,experience:-1)))
        XCTAssertTrue(e.state.resting);XCTAssertEqual(e.state.strength,85);XCTAssertEqual(e.state.storedStrength,5)
        XCTAssertEqual(e.state.progress?.counters?["stat_say_money_d"],1)
        XCTAssertEqual(e.state.progress?.counters?["stat_say_like_p"],1)
        XCTAssertEqual(e.state.progress?.counters?["stat_say_exp_d"],1)
        let before=e.state;XCTAssertFalse(e.applySelectionDialogue(PetDialogueEffects(money:.nan)));XCTAssertEqual(e.state,before)
        XCTAssertEqual(try JSONDecoder().decode(PetState.self,from:JSONEncoder().encode(e.state)),e.state)
    }
    func testCatalogValidationAndCaseSensitiveCharacterFilter() throws {
        let c=FixedWallClock();var e=entry("one");e.characterTags=["All"]
        let d=try session([e],clock:c);d.refresh(state:PetState());XCTAssertTrue(d.choices.isEmpty)
        for invalid in [entry("one",bounds:["foodmin":2,"foodmax":1]),entry("one",effects:PetDialogueEffects(affection:51)),entry("one",bounds:["unknown":0])] {
            XCTAssertThrowsError(try session([invalid],clock:c))
        }
        XCTAssertThrowsError(try session([entry("a"),entry("a")],clock:c))
    }
    func testSeededPoolRepeatabilityAndClockJumpDoesNotApplyEffects() throws {
        let c=FixedWallClock(),catalog=PetSelectionCatalog(tags:["all"],entries:(0..<12).map { entry("n\($0)") })
        let a=try PetSelectionSession(catalog:catalog,clock:c,random:SeededPetRandom(seed:9))
        let b=try PetSelectionSession(catalog:catalog,clock:c,random:SeededPetRandom(seed:9))
        a.refresh(state:PetState());b.refresh(state:PetState());XCTAssertEqual(a.choices.map(\.id),b.choices.map(\.id))
        let old=a.choices.map(\.id);c.now=c.now.addingTimeInterval(-1000)
        a.refresh(state:PetState());XCTAssertEqual(a.choices.map(\.id),old)
        c.now=c.now.addingTimeInterval(5000);a.refresh(state:PetState())
        XCTAssertEqual(a.deadline,c.now.addingTimeInterval(600))
    }
    func testStatisticsOverflowRollsBackStateAndLeavesChoiceAvailable() throws {
        let c=FixedWallClock();var s=PetState();s.progress=PetProgress();s.progress?.counters=["stat_say_money_p":1e12]
        let engine=PetEngine(state:s,clock:FakeClock(),wallClock:c),d=try session([entry("one",effects:PetDialogueEffects(money:2))],clock:c)
        d.refresh(state:engine.state);let before=engine.state,deadline=d.deadline
        XCTAssertNil(d.select(id:"one") { engine.applySelectionDialogue($0) ? engine.state:nil })
        XCTAssertEqual(engine.state,before);XCTAssertEqual(d.deadline,deadline);XCTAssertEqual(d.choices.map(\.id),["one"])
    }

}
