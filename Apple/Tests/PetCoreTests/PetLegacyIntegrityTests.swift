import XCTest
@testable import PetCore

final class PetLegacyIntegrityTests: XCTestCase {
    private func fixture() throws -> [String:Any] {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Tests/Fixtures/legacy-integrity.json"))) as? [String:Any])
    }
    private func samples() throws -> [[String:Any]] { try XCTUnwrap(fixture()["cases"] as? [[String:Any]]) }
    private func inspect(_ input:String) throws -> PetLegacyIntegrity.Result { PetLegacyIntegrity.inspect(try PetLegacyLPSDocument.parse(Data(input.utf8))) }
    func testOriginalDocumentSerializationBytes() throws {
        for sample in try XCTUnwrap(fixture()["serializations"] as? [[String:Any]]) {
            let input=try XCTUnwrap(sample["input"] as? String),expected=try XCTUnwrap(sample["canonical"] as? String)
            XCTAssertEqual(Array(try PetLegacyLPSDocument.parse(Data(input.utf8)).canonicalString.utf8),Array(expected.utf8))
        }
    }
    func testAllOriginalHashBranchesMatchRealOracle() throws {
        for sample in try samples() {
            let result=try inspect(XCTUnwrap(sample["input"] as? String))
            XCTAssertEqual(result.status,.verified)
            XCTAssertEqual(result.path.rawValue,sample["path"] as? String)
            XCTAssertEqual(result.scope.rawValue,sample["scope"] as? String)
            let expected=try XCTUnwrap(Int64(XCTUnwrap(sample["expected"] as? String)))
            XCTAssertEqual(result.expected,expected);XCTAssertEqual(result.calculated,expected)
        }
    }
    func testRootHashDetectsRawValueChanges() throws {
        for sample in try samples().filter({ $0["scope"] as? String == "document" }) {
            let input=try XCTUnwrap(sample["input"] as? String)
            XCTAssertEqual(try inspect(input.replacingOccurrences(of:"money#1234500000000",with:"money#1234500000001")).status,.mismatch)
            XCTAssertEqual(try inspect(input.replacingOccurrences(of:"///external",with:"///modified")).status,.mismatch)
        }
    }
    func testLegacyPetHashPriorityAndLimitedCoverage() throws {
        let sample=try XCTUnwrap(samples().first { $0["scope"] as? String == "pet" });let input=try XCTUnwrap(sample["input"] as? String)
        let outside=try inspect(input.replacingOccurrences(of:"///external",with:"///modified"))
        XCTAssertEqual(outside.status,.verified);XCTAssertEqual(outside.scope,.pet)
        XCTAssertEqual(try inspect(input.replacingOccurrences(of:"money#1234500000000",with:"money#1234500000001")).status,.mismatch)
        XCTAssertEqual(outside.path,.legacyPetMD5) // Unrecognized root hash version is not consulted on the original pet route.
    }
    func testMissingAmbiguousFutureAndInvalidHashInputs() throws {
        XCTAssertEqual(try inspect("vpet:|name#小宠:|").status,.missing)
        for input in ["hash#0:|ver#99:|", "hash#0:|ver#2:|ver#2:|", "hash#0:|ver#2:|\nhash#0:|ver#2:|", "hash#9223372036854775808:|ver#2:|", "hash#1.0:|ver#2:|", "vpet:|hash#1:|hash#2:|", "vpet:|hash#1:|\nvpet:|hash#2:|"] {
            XCTAssertEqual(try inspect(input).status,.unsupported,input)
        }
        XCTAssertEqual(try inspect("vpet:|\nhash#-1:|ver#2:|").status,.mismatch)
    }
    func testCRLFBOMAndCanonicalFormattingAreNotRawFileHashing() throws {
        let input=try XCTUnwrap(samples()[0]["input"] as? String)
        let changed="\u{feff}\r\n"+input.replacingOccurrences(of:"\n",with:"\r\n")+"\r\n"
        XCTAssertEqual(try inspect(changed).status,.verified)
        XCTAssertEqual(try inspect(changed).calculated,try inspect(input).calculated)
    }
    func testPreviewReportsActualIntegrityAndKeepsWholeSource() throws {
        for sample in try samples() {
            let bytes=Data(try XCTUnwrap(sample["input"] as? String).utf8);let preview=try PetLegacySavePreview(data:bytes)
            XCTAssertEqual(preview.integrity.status,.verified);XCTAssertEqual(preview.sourceData,bytes)
            XCTAssertFalse(preview.issues.contains { $0.path=="hash" && $0.severity == .blocking })
            if preview.integrity.scope == .pet { XCTAssertTrue(preview.issues.contains { $0.path=="hash" && $0.message.contains("仅") }) }
        }
        let input=try XCTUnwrap(samples()[0]["input"] as? String).replacingOccurrences(of:"money#1234500000000",with:"money#1234500000001")
        XCTAssertTrue(try PetLegacySavePreview(data:Data(input.utf8)).issues.contains { $0.path=="hash" && $0.severity == .blocking })
    }
}
