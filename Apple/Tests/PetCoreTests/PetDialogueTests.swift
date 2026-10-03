import XCTest
@testable import PetCore
final class PetDialogueTests: XCTestCase {
    var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testOriginalHourBoundariesAndNumericBounds() throws {
        let catalog=try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json"))
        XCTAssertEqual(catalog.entries.count,671)
        var entry=try XCTUnwrap(catalog.entries.first { $0.kind == "click" });entry.bounds=[:];entry.mode=2;entry.workState="Nomal";entry.working=nil;entry.dayTime=1
        var state=PetState()
        XCTAssertFalse(entry.matchesClick(state:state,activityName:nil,hour:5))
        XCTAssertTrue(entry.matchesClick(state:state,activityName:nil,hour:6));XCTAssertTrue(entry.matchesClick(state:state,activityName:nil,hour:11))
        XCTAssertFalse(entry.matchesClick(state:state,activityName:nil,hour:12))
        entry.bounds=["likemin":40,"likemax":70];state.affection=40
        XCTAssertTrue(entry.matchesClick(state:state,activityName:nil,hour:6));state.affection=70.1
        XCTAssertFalse(entry.matchesClick(state:state,activityName:nil,hour:6))
        entry.bounds=[:];entry.workState="Work";entry.working="写论文"
        state.activity=ActivitySession(activityID:"test")
        XCTAssertTrue(entry.matchesClick(state:state,activityName:"写论文",hour:6))
        state.activity?.isPaused=true
        XCTAssertFalse(entry.matchesClick(state:state,activityName:"写论文",hour:6))
    }
    func testLowStateThresholdsAndStrictAffectionComparison() throws {
        let catalog=try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json"))
        var entry=try XCTUnwrap(catalog.entries.first { $0.kind == "food" });entry.lowMode="H";entry.severity="L";entry.like=0
        var state=PetState();state.food=69.9
        XCTAssertTrue(entry.matchesLow(state:state,kind:"food"));state.food=state.strengthMax*0.7
        XCTAssertFalse(entry.matchesLow(state:state,kind:"food"))
        entry.lowMode="L";state.health=30;state.food=50;state.affection=0
        XCTAssertFalse(entry.matchesLow(state:state,kind:"food"));state.affection=40
        XCTAssertTrue(entry.matchesLow(state:state,kind:"food"));entry.like=1
        XCTAssertFalse(entry.matchesLow(state:state,kind:"food"))
    }
    func testAutomaticTextHasNoCatchUpAndSeededSelectionIsRepeatable() throws {
        let catalog=try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json"))
        let clock=FakeClock(),dialogue=PetDialogue(catalog:catalog,clock:clock,random:FixedRandom())
        var state=PetState();state.food=65
        clock.now=15;XCTAssertNil(dialogue.automatic(state:state,eligible:false))
        clock.now=30;XCTAssertEqual(dialogue.automatic(state:state,eligible:true)?.kind,"food")
        clock.now=31;XCTAssertNil(dialogue.automatic(state:state,eligible:true))
        clock.now=1000;XCTAssertNil(dialogue.automatic(state:state,eligible:true))
        clock.now=1015;XCTAssertEqual(dialogue.automatic(state:state,eligible:true)?.kind,"food")
        func sequence() -> [String?] {
            let c=FakeClock(),d=PetDialogue(catalog:catalog,clock:c,random:SeededPetRandom(seed:7))
            return (0..<20).map { c.now=Double($0)*21;return d.click(state:state,gameplay:PetCatalog(),hour:10)?.id }
        }
        XCTAssertEqual(sequence(),sequence())
        let engine=PetEngine();let before=engine.state
        XCTAssertFalse(engine.applyDialogue(PetDialogueEffects(money:.nan)))
        XCTAssertEqual(engine.state,before)
    }
    func testCooldownDeterminismAndEffectsApplyWithoutWakingPet() throws {
        let catalog=try PetDialogueCatalog.load(from:root.appendingPathComponent("dialogue.json"))
        let clock=FakeClock(),gameplay=PetCatalog(),state=PetState()
        let dialogue=PetDialogue(catalog:catalog,clock:clock,random:FixedRandom())
        XCTAssertNotNil(dialogue.click(state:state,gameplay:gameplay,hour:10))
        clock.now=20;XCTAssertNil(dialogue.click(state:state,gameplay:gameplay,hour:10))
        clock.now=20.01;XCTAssertNotNil(dialogue.click(state:state,gameplay:gameplay,hour:10))
        var asleep=state;asleep.resting=true;asleep.strength=80
        let engine=PetEngine(state:asleep)
        XCTAssertTrue(engine.applyDialogue(PetDialogueEffects(money:-1,strength:10,feeling:2,experience:1)))
        XCTAssertTrue(engine.state.resting);XCTAssertEqual(engine.state.money,99)
        XCTAssertEqual(engine.state.strength,85);XCTAssertEqual(engine.state.storedStrength,5)
        XCTAssertEqual(engine.state.feeling,62);XCTAssertEqual(engine.state.experience,1)
    }
}
