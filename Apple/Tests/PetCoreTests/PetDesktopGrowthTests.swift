import XCTest
@testable import PetCore
final class PetDesktopGrowthTests:XCTestCase {
    func testLevelThresholdAndNegativeExperienceNeverDemotes() throws {
        var g=try PetDesktopGrowth()
        XCTAssertEqual(g.strengthMax,104);XCTAssertEqual(g.feelingMax,102);XCTAssertEqual(g.affectionMax,100)
        XCTAssertNil(try g.setExperience(99));XCTAssertEqual(g.level,1)
        let change=try XCTUnwrap(g.setExperience(100));XCTAssertEqual(g.level,2);XCTAssertEqual(g.experience,0);XCTAssertEqual(g.affectionMax,110)
        XCTAssertEqual(change.beforeLevel,1);XCTAssertEqual(change.afterLevel,2);XCTAssertEqual(change.levelUps,1);XCTAssertFalse(change.didPrestige)
        XCTAssertNil(try g.addExperience(-2));XCTAssertEqual(g.level,2);XCTAssertEqual(g.experience,-2)
        XCTAssertNil(try g.addExperience(301));XCTAssertEqual(g.experience,299)
        XCTAssertNotNil(try g.addExperience(1));XCTAssertEqual(g.level,3);XCTAssertEqual(g.experience,0)
    }
    func testStrictPrestigeBoundaryAndContinuationInSameAssignment() throws {
        var g=try PetDesktopGrowth(level:1000,affectionMax:10090)
        XCTAssertNil(try g.setExperience(199899));XCTAssertEqual(g.prestige,0)
        let c=try XCTUnwrap(g.setExperience(199900+19900))
        XCTAssertEqual(g.level,101);XCTAssertEqual(g.prestige,1);XCTAssertEqual(g.experience,0);XCTAssertEqual(g.affectionMax,10110)
        XCTAssertTrue(c.didPrestige);XCTAssertEqual(c.levelUps,2);XCTAssertEqual(c.beforeLevel,1000);XCTAssertEqual(c.afterLevel,101)
        g=try PetDesktopGrowth(level:1100,prestige:1,affectionMax:7)
        XCTAssertNotNil(try g.setExperience(219900));XCTAssertEqual(g.level,200);XCTAssertEqual(g.prestige,2);XCTAssertEqual(g.affectionMax,17)
    }
    func testBulkAssignmentMatchesOriginalLoopAcrossRepeatedPrestige() throws {
        for input in [0.0,100,400,99999999,100000000,220019900,1e9,9e9] {
            var g=try PetDesktopGrowth();let c=try g.setExperience(input)
            var level=1,prestige=0,count=0;var remaining=input,affection=100.0
            while remaining>=Double(200*level-100) {
                remaining-=Double(200*level-100);level+=1;count+=1;affection+=10
                if level>1000+100*prestige { prestige+=1;level=100*prestige }
            }
            XCTAssertEqual(g.level,level);XCTAssertEqual(g.prestige,prestige);XCTAssertEqual(g.experience,remaining);XCTAssertEqual(g.affectionMax,affection)
            XCTAssertEqual(c?.levelUps ?? 0,count)
        }
    }
    func testDerivedCapsAndDesktopMoodSourceQuirk() throws {
        let g=try PetDesktopGrowth(level:10,prestige:2,affectionMax:321)
        XCTAssertEqual(g.strengthMax,151);XCTAssertEqual(g.feelingMax,125);XCTAssertEqual(g.affectionMax,321)
        XCTAssertEqual(g.mood(health:60,feeling:100,affection:0),.poor) // Desktop ratio>=80 does not reduce health threshold.
        XCTAssertEqual(g.mood(health:30,feeling:100,affection:0),.ill)
        XCTAssertEqual(g.mood(health:61,feeling:112.5,affection:0),.happy)
        XCTAssertEqual(g.mood(health:61,feeling:56.25,affection:0),.poor)
        XCTAssertEqual(g.mood(health:48,feeling:100,affection:80),.poor)
        XCTAssertEqual(g.mood(health:24,feeling:100,affection:80),.ill)
    }
    func testInvalidAssignmentAndPrestigeLimitAreTransactional() throws {
        var g=try PetDesktopGrowth();let before=g
        for bad in [Double.nan,Double.infinity,1e12+1] {
            XCTAssertThrowsError(try g.setExperience(bad));XCTAssertEqual(g,before)
        }
        g=try PetDesktopGrowth(level:1001000,prestige:10000);let capped=g
        XCTAssertThrowsError(try g.setExperience(200199900));XCTAssertEqual(g,capped)
        g=try PetDesktopGrowth(affectionMax:1e12);let affection=g
        XCTAssertThrowsError(try g.setExperience(100));XCTAssertEqual(g,affection)
        XCTAssertThrowsError(try PetDesktopGrowth(level:0));XCTAssertThrowsError(try PetDesktopGrowth(prestige:-1))
    }
    func testCodableRejectsInvalidStatesAndKeepsCustomAffectionLimit() throws {
        let g=try PetDesktopGrowth(level:17,prestige:2,experience:-10,affectionMax:777)
        XCTAssertEqual(try JSONDecoder().decode(PetDesktopGrowth.self,from:JSONEncoder().encode(g)),g)
        let invalid=Data(#"{"level":0,"prestige":0,"experience":0,"affectionMax":100}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(PetDesktopGrowth.self,from:invalid))
    }
    func testLargeGainIsDeterministicAndMatchesPartitionedGains() throws {
        var a=try PetDesktopGrowth(),b=a
        _=try a.addExperience(1e12)
        for _ in 0..<100 { _=try b.addExperience(1e10) }
        XCTAssertEqual(a,b);XCTAssertLessThan(a.experience,Double(200*a.level-100));XCTAssertGreaterThan(a.prestige,0)
    }
}
