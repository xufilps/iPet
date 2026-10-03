import XCTest
@testable import PetCore

final class PetLegacySavePreviewTests: XCTestCase {
    private func sample() throws -> (String,[String:Any]) {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Tests/Fixtures/legacy-pet-fields.json"))) as? [String:Any])
        return (try XCTUnwrap(object["input"] as? String),try XCTUnwrap(object["expected"] as? [String:Any]))
    }
    func testOriginalSerializerFieldsMapWithoutUnitLoss() throws {
        let (input,expected)=try sample();let preview=try PetLegacySavePreview(data:Data(input.utf8));let state=try XCTUnwrap(preview.petState)
        XCTAssertEqual(state.name,expected["name"] as? String);XCTAssertEqual(preview.hostName,expected["hostName"] as? String)
        XCTAssertEqual(state.level,expected["level"] as? Int);XCTAssertEqual(state.growth?.prestige,0)
        for (key,value) in [("money",state.money),("experience",state.experience),("strength",state.strength),("food",state.food),("drink",state.drink),("feeling",state.feeling),("health",state.health),("affection",state.affection),("affectionMax",state.affectionMax),("storedStrength",state.storedStrength),("storedFood",state.storedFood),("storedDrink",state.storedDrink)] {
            XCTAssertEqual(value,try XCTUnwrap(expected[key] as? Double),key)
        }
        XCTAssertEqual(state.affectionMax,150.25);XCTAssertEqual(state.money,1234.5)
        XCTAssertEqual(preview.savedMode,"Happy");try state.validate()
    }
    func testNegativeExperienceAndCrossingUseDesktopModel() throws {
        let (input,_)=try sample()
        let negative=try PetLegacySavePreview(data:Data(input.replacingOccurrences(of:"exp#50000000000",with:"exp#-1000000000").utf8))
        XCTAssertEqual(negative.petState?.level,10);XCTAssertEqual(negative.petState?.experience,-1)
        let crossed=try PetLegacySavePreview(data:Data(input.replacingOccurrences(of:"exp#50000000000",with:"exp#2000000000000").utf8))
        XCTAssertEqual(crossed.petState?.level,11);XCTAssertEqual(crossed.petState?.experience,100)
        XCTAssertEqual(crossed.petState?.affectionMax,150.25)
        XCTAssertTrue(crossed.issues.contains { $0.path=="vpet.exp" })
    }
    func testOriginalIgnoreCaseOnlyAppliesToAnnotatedFields() throws {
        let (input,_)=try sample()
        let mixed=input.replacingOccurrences(of:"strength#",with:"STRENGTH#").replacingOccurrences(of:"strengthFood#",with:"StrengthFood#")
        let preview=try PetLegacySavePreview(data:Data(mixed.utf8))
        XCTAssertEqual(preview.petState?.strength,115.5);XCTAssertEqual(preview.petState?.food,0)
        XCTAssertTrue(preview.issues.contains { $0.path=="vpet.StrengthFood" && $0.severity == .blocking })
    }
    func testAmbiguousFieldsAndRootsBlockPetCandidate() throws {
        let (input,_)=try sample()
        XCTAssertNil(try PetLegacySavePreview(data:Data((input+"\n"+input).utf8)).petState)
        XCTAssertNil(try PetLegacySavePreview(data:Data(input.replacingOccurrences(of:"name#",with:"name#first:|name#").utf8)).petState)
        XCTAssertNil(try PetLegacySavePreview(data:Data(input.replacingOccurrences(of:"strength#",with:"STRENGTH#1:|strength#").utf8)).petState)
        XCTAssertNil(try PetLegacySavePreview(data:Data("old#name:|".utf8)).petState)
        XCTAssertNil(try PetLegacySavePreview(data:Data(input.replacingOccurrences(of:"vpet:|",with:"vpet#old:|").utf8)).petState)
    }
    func testMissingDefaultsAndInvalidScalarsAreExplicit() throws {
        let minimal=try PetLegacySavePreview(data:Data("vpet:|name#小宠:|".utf8))
        XCTAssertEqual(minimal.petState?.money,0);XCTAssertEqual(minimal.petState?.level,1)
        XCTAssertEqual(minimal.petState?.health,0);XCTAssertEqual(minimal.petState?.affectionMax,100)
        XCTAssertEqual(minimal.hostName,"");XCTAssertTrue(minimal.issues.contains { $0.path=="vpet.money" })
        let (input,_)=try sample()
        for (old,new) in [("Level#10","Level#2147483648"),("money#1234500000000","money#1234.5"),("LikabilityMax#150.25","LikabilityMax#NaN"),("health#82000000000","health#101000000000"),("name#萝莉斯","name#")] {
            XCTAssertNil(try PetLegacySavePreview(data:Data(input.replacingOccurrences(of:old,with:new).utf8)).petState,new)
        }
    }
    func testWholeSaveGapsAndSourceBytesArePreserved() throws {
        let (input,_)=try sample();let bytes=Data((input+"\nitem0:|name#自定义:|Count#2:|\nstatistics:|old#text:|\nhash#-1:|ver#2:|\nplugin:|custom#x:|").utf8)
        let preview=try PetLegacySavePreview(data:bytes)
        XCTAssertEqual(preview.sourceData,bytes);XCTAssertEqual(preview.document.lines.count,5)
        XCTAssertNotNil(preview.petState)
        for path in ["item0","statistics","hash","plugin","vpet.hostname"] {
            XCTAssertTrue(preview.issues.contains { $0.path==path && $0.severity == .blocking },path)
        }
        XCTAssertTrue(preview.petState?.inventory.isEmpty == true) // Candidate is only the pet subset, never an importable whole save.
    }
    func testUnknownFieldsDiagnosticsAreBoundedWithoutDiscardingSource() throws {
        let (input,_)=try sample();let extra=(0..<250).map { "unknown\($0)#x:|" }.joined();let bytes=Data((input+extra).utf8)
        let preview=try PetLegacySavePreview(data:bytes)
        XCTAssertEqual(preview.issues.count,200);XCTAssertGreaterThan(preview.omittedIssueCount,0)
        XCTAssertEqual(preview.sourceData,bytes);XCTAssertEqual(preview.document.lines[0].fields.count,267)
    }
    func testMissingAffectionLimitRetainsExperienceSetterIncrements() throws {
        let preview=try PetLegacySavePreview(data:Data("vpet:|name#小宠:|Level#1:|exp#100000000000:|".utf8))
        XCTAssertEqual(preview.petState?.level,2)
        XCTAssertEqual(preview.petState?.affectionMax,110)
        XCTAssertTrue(preview.issues.contains { $0.path=="vpet.mode" })
    }
    func testUnknownModeBlocksCandidate() throws {
        let (input,_)=try sample()
        for mode in ["Bogus","HAPPY",""] {
            let preview=try PetLegacySavePreview(data:Data(input.replacingOccurrences(of:"mode#Happy",with:"mode#"+mode).utf8))
            XCTAssertNil(preview.petState)
            XCTAssertTrue(preview.issues.contains { $0.path=="vpet.mode" && $0.severity == .blocking })
        }
    }
    func testStoredModeIsReportedAndNotForcedIntoNativeMood() throws {
        let (input,_)=try sample();let preview=try PetLegacySavePreview(data:Data(input.replacingOccurrences(of:"mode#Happy",with:"mode#Ill").utf8))
        XCTAssertEqual(preview.savedMode,"Ill");XCTAssertEqual(preview.petState?.mood,.happy)
        XCTAssertTrue(preview.issues.contains { $0.path=="vpet.mode" })
    }
}
