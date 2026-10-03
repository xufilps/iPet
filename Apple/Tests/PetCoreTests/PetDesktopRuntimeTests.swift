import XCTest
@testable import PetCore
final class PetDesktopRuntimeTests:XCTestCase {
    func store() throws -> PetSaveStore {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:url) };return PetSaveStore(directory:url)
    }
    func oldData(experience:Double=100,affection:Double=109) throws -> Data {
        // Use an explicit old schema, not a v8 state relabeled as legacy.
        var object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(PetSaveDocument(state:PetState()))) as! [String:Any]
        object["version"]=7;var state=object["state"] as! [String:Any]
        state.removeValue(forKey:"growth");state["experience"]=experience;state["affection"]=affection;state["money"]=1234
        state["inventory"]=["unknown":3];object["state"]=state
        return try JSONSerialization.data(withJSONObject:object,options:.sortedKeys)
    }
    func testNewPetUsesDesktopGrowthAndNegativeExperienceDoesNotDemote() throws {
        var s=PetState();XCTAssertNotNil(s.growth);XCTAssertEqual(s.money,100);XCTAssertEqual(s.strengthMax,104);XCTAssertEqual(s.feelingMax,102)
        s.experience=100;XCTAssertEqual(s.level,2);XCTAssertEqual(s.experience,0);XCTAssertEqual(s.affectionMax,110)
        s.experience = -1;XCTAssertEqual(s.level,2);XCTAssertEqual(s.experience,-1);try s.validate()
        s.experience=300;XCTAssertEqual(s.level,3);XCTAssertEqual(s.experience,0)
    }
    func testDynamicCapsSideEffectsAndTouchCeiling() throws {
        var s=PetState();s.experience=8100
        XCTAssertEqual(s.level,10);XCTAssertEqual(s.strengthMax,122);XCTAssertEqual(s.feelingMax,111)
        s.strength=120;s.changeStrength(10);XCTAssertEqual(s.strength,122)
        s.food=121;s.changeFood(10);XCTAssertEqual(s.food,122)
        s.drink=121;s.changeDrink(10);XCTAssertEqual(s.drink,122)
        s.feeling=110;s.changeFeeling(10);XCTAssertEqual(s.feeling,111)
        let e=PetEngine(state:s);_ = e.send(.touchHead);XCTAssertEqual(e.state.strength,122)
        s.feeling=100;s.strength=120;let touching=PetEngine(state:s);_=touching.send(.touchHead)
        XCTAssertEqual(touching.state.strength,118);XCTAssertEqual(touching.state.feeling,101)
        try touching.state.validate()
    }
    func testDesktopMoodAndFractionalDailyThresholds() {
        var s=PetState();s.experience=8100;s.health=60;s.feeling=100
        XCTAssertEqual(s.mood,.poor)
        s.health=61;s.feeling=75 // Below 75% of111; no extra experience/health.
        let c=FakeClock(),e=PetEngine(state:s,clock:c,random:FixedRandom());c.now=15;e.tick()
        XCTAssertEqual(e.state.experience,0.05,accuracy:1e-10);XCTAssertEqual(e.state.health,61)
        XCTAssertEqual(e.state.strength,100.1,accuracy:1e-8)
    }
    func testFeedingCrossesLevelBeforeRemainingEffectsAndRejectsInvalidGrowth() throws {
        var s=PetState();s.experience=99;s.strength=103
        let e=PetEngine(state:s)
        XCTAssertTrue(e.applyDialogue(PetDialogueEffects(strength:10,experience:1)))
        XCTAssertEqual(e.state.level,2);XCTAssertEqual(e.state.experience,0);XCTAssertEqual(e.state.strength,106)
        let before=e.state;XCTAssertFalse(e.applyDialogue(PetDialogueEffects(experience:.infinity)));XCTAssertEqual(e.state,before)
        s.experience = .nan;XCTAssertThrowsError(try s.validate())
        var capped=PetState();capped.growth=try PetDesktopGrowth(experience:99,affectionMax:1e12);capped.experience=99
        let limited=PetEngine(state:capped),checkpoint=limited.state
        XCTAssertFalse(limited.applyDialogue(PetDialogueEffects(strength:10,experience:1)))
        XCTAssertEqual(limited.state,checkpoint) // A finite effect can fail after mutating; no silent dropped experience.

    }
    func testV7PreviewMigrationPreservesHistoricalAffectionAndOriginalBytes() throws {
        let store=try store(),data=try oldData(experience:50,affection:123)
        try data.write(to:store.primary)
        let s=try store.previewImport(data);XCTAssertEqual(s.level,1);XCTAssertEqual(s.experience,50);XCTAssertEqual(s.affection,123);XCTAssertEqual(s.affectionMax,123)
        XCTAssertEqual(s.money,1234);XCTAssertEqual(s.inventory["unknown"],3)
        XCTAssertEqual(try Data(contentsOf:store.primary),data)
        let loaded=try XCTUnwrap(store.load());try store.save(loaded)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),data)
        XCTAssertEqual(try store.load(),loaded);XCTAssertEqual(PetSaveDocument(state:loaded).version,8)
    }
    func testCumulativeV7MigrationAndPrestigeConversion() throws {
        let store=try store();let s=try store.previewImport(oldData(experience:8150,affection:2))
        XCTAssertEqual(s.level,10);XCTAssertEqual(s.experience,50);XCTAssertEqual(s.affectionMax,190)
        let high=try store.previewImport(oldData(experience:100000000,affection:0))
        XCTAssertEqual(high.level,100);XCTAssertEqual(high.growth?.prestige,1);XCTAssertEqual(high.experience,0);XCTAssertEqual(high.affectionMax,10100)
    }
    func testNativeV8RequiresGrowthAndConsistentExperience() throws {
        let store=try store();var object=try JSONSerialization.jsonObject(with:store.exportSnapshot(PetState())) as! [String:Any]
        var state=object["state"] as! [String:Any];state.removeValue(forKey:"growth");object["state"]=state
        XCTAssertThrowsError(try store.previewImport(JSONSerialization.data(withJSONObject:object)))
        object=try JSONSerialization.jsonObject(with:store.exportSnapshot(PetState())) as! [String:Any];state=object["state"] as! [String:Any];state["experience"]=50;object["state"]=state
        XCTAssertThrowsError(try store.previewImport(JSONSerialization.data(withJSONObject:object)))
        var invalid=PetState();invalid.growth=nil;XCTAssertThrowsError(try store.save(invalid));XCTAssertThrowsError(try store.exportSnapshot(invalid))
    }
    func testOldBoundsRemainStrictAndFutureMainBackupProtected() throws {
        let store=try store();var object=try JSONSerialization.jsonObject(with:oldData()) as! [String:Any]
        var state=object["state"] as! [String:Any];state["strength"]=102;object["state"]=state
        XCTAssertThrowsError(try store.previewImport(JSONSerialization.data(withJSONObject:object)))
        let data=try oldData();try data.write(to:store.primary);let loaded=try XCTUnwrap(store.load())
        let future=Data(#"{"version":9}"#.utf8);try future.write(to:store.backup)
        XCTAssertThrowsError(try store.save(loaded));XCTAssertEqual(try Data(contentsOf:store.primary),data);XCTAssertEqual(try Data(contentsOf:store.backup),future)
        try future.write(to:store.primary);XCTAssertThrowsError(try store.load())
    }
    func testDynamicFullStatisticsAndGrowthCodableExtremes() throws {
        var s=PetState();s.experience=8100;s.strength=100;s.food=100;s.drink=100;s.feeling=100
        var p=PetProgress();p.recordSample(state:s,catalog:PetCatalog());XCTAssertNil(p.counters?["stat_100_all"])
        s.strength=s.strengthMax;s.food=s.strengthMax;s.drink=s.strengthMax;s.feeling=s.feelingMax
        p.recordSample(state:s,catalog:PetCatalog());XCTAssertEqual(p.counters?["stat_100_all"],1)
        for values in [(Int.max,0,0.0,100.0),(1,Int.max,0.0,100.0),(1,0,100.0,100.0),(1,0,0.0,1e12+1)] {
            let data=try JSONSerialization.data(withJSONObject:["level":values.0,"prestige":values.1,"experience":values.2,"affectionMax":values.3])
            XCTAssertThrowsError(try JSONDecoder().decode(PetDesktopGrowth.self,from:data))
        }
    }
    func testLowTextThresholdsUseDynamicStrengthMaximum() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets/dialogue.json")
        var entry=try XCTUnwrap(PetDialogueCatalog.load(from:root).entries.first { $0.kind=="food" })
        entry.lowMode="H";entry.severity="L";entry.like=0
        var s=PetState();s.experience=8100;s.food=80
        XCTAssertTrue(entry.matchesLow(state:s,kind:"food")) // 80/122 is between60% and70%.
        s.food=s.strengthMax*0.7;XCTAssertFalse(entry.matchesLow(state:s,kind:"food"))
    }

    func testPrestigeRetainsHistoricalAttributesAndSavesUntilNextMutation() throws {
        var s=PetState();s.growth=try PetDesktopGrowth(level:1000,experience:199899.95,affectionMax:10090)
        s.experience=199899.95;s.strength=s.strengthMax;s.feeling=s.feelingMax;s.food=20;s.drink=20
        try s.validate()
        let c=FakeClock(),e=PetEngine(state:s,clock:c,random:FixedRandom());c.now=15;e.tick()
        XCTAssertEqual(e.state.growth?.prestige,1);XCTAssertEqual(e.state.level,100)
        XCTAssertEqual(e.state.strength,811);XCTAssertEqual(e.state.feeling,455)
        XCTAssertEqual(e.state.strengthMax,312);XCTAssertEqual(e.state.feelingMax,206)
        try e.state.validate()
        let store=try store();try store.save(e.state);XCTAssertEqual(try store.load(),e.state)
        var clamped=e.state;clamped.changeStrength(0);clamped.changeFeeling(0)
        XCTAssertEqual(clamped.strength,312);XCTAssertEqual(clamped.feeling,206);try clamped.validate()
        var impossible=e.state;impossible.strength=812;XCTAssertThrowsError(try impossible.validate())
    }
    func testStudyCompletionPrestigePreservesAllRawAttributes() throws {
        var s=PetState();s.growth=try PetDesktopGrowth(level:1000,experience:199899,affectionMax:10090);s.experience=199899
        s.strength=s.strengthMax;s.food=s.strengthMax;s.drink=s.strengthMax;s.feeling=s.feelingMax
        s.activity=ActivitySession(activityID:"work");s.activity?.earned=10
        let c=FakeClock(),e=PetEngine(state:s,clock:c,catalog:PetCatalog(activities:[testWork(kind:.study,seconds:1)]))
        c.now=1;e.tick();c.now=1.1;e.tick()
        XCTAssertNil(e.state.activity);XCTAssertEqual(e.state.level,100);XCTAssertEqual(e.state.growth?.prestige,1)
        XCTAssertEqual(e.state.food,811);XCTAssertEqual(e.state.drink,811)
        try e.state.validate();let store=try store();try store.save(e.state);XCTAssertEqual(try store.load(),e.state)
    }

}
