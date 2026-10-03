import XCTest
@testable import PetCore

final class PetLegacyLPSTests: XCTestCase {
    private func fixture() throws -> [String:Any] {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Tests/Fixtures/legacy-lps-v1.11.9.json"))) as? [String:Any])
    }
    func testFixedLibraryStructuralOracle() throws {
        let cases=try XCTUnwrap(fixture()["cases"] as? [[String:Any]])
        for item in cases {
            let input=try XCTUnwrap(item["input"] as? String)
            let actual=try PetLegacyLPSDocument.parse(Data(input.utf8))
            let expected=try XCTUnwrap(item["lines"] as? [[String:Any]])
            XCTAssertEqual(actual.lines.count,expected.count)
            for (line,object) in zip(actual.lines,expected) {
                XCTAssertEqual(line.name,object["name"] as? String)
                XCTAssertEqual(line.rawInfo,object["rawInfo"] as? String)
                XCTAssertEqual(line.info,object["info"] as? String)
                XCTAssertEqual(line.rawText,object["rawText"] as? String)
                XCTAssertEqual(line.text,object["text"] as? String)
                XCTAssertEqual(line.comment,object["comment"] as? String)
                let lookups=try XCTUnwrap(object["lookups"] as? [[String:Any]])
                for lookup in lookups {
                    XCTAssertEqual(line.firstField(named:try XCTUnwrap(lookup["name"] as? String))?.info,lookup["info"] as? String)
                }
                let fields=try XCTUnwrap(object["fields"] as? [[String:Any]])
                XCTAssertEqual(line.fields.count,fields.count)
                for (field,object) in zip(line.fields,fields) {
                    XCTAssertEqual(field.name,object["name"] as? String)
                    XCTAssertEqual(field.rawInfo,object["rawInfo"] as? String)
                    XCTAssertEqual(field.info,object["info"] as? String)
                }
            }
        }
    }
    func testFixedPointNumbersFromOriginalLibrary() throws {
        let numbers=try XCTUnwrap(fixture()["numbers"] as? [[String:Any]])
        for number in numbers {
            XCTAssertEqual(try PetLegacyLPSDocument.storedFloat(XCTUnwrap(number["stored"] as? String)),try XCTUnwrap(number["decoded"] as? Double))
        }
        XCTAssertEqual(try PetLegacyLPSDocument.storedFloat("100"),0.0000001)
        XCTAssertEqual(try PetLegacyLPSDocument.storedFloat(String(Int64.min)),Double(Int64.min)/1e9)
    }
    func testDuplicateAndCaseSensitiveLookupPreservesOrder() throws {
        let document=try PetLegacyLPSDocument.parse(Data("vpet:|name#first:|name#second:|Name#upper:|\nvpet:|name#other:|".utf8))
        XCTAssertEqual(document.lines.count,2)
        XCTAssertEqual(document.lines[0].fields.map(\.name),["name","name","Name"])
        XCTAssertEqual(document.lines[0].firstField(named:"name")?.info,"first")
        XCTAssertEqual(document.lines[0].firstField(named:"Name")?.info,"upper")
        XCTAssertNil(document.lines[0].firstField(named:"NAME"))
    }
    func testInvalidNumbersDoNotGuessLocaleOrSilentlyOverflow() {
        for raw in ["", " 1", "+1", "01", "-0", "1.0", "1e9", "1,000", "NaN", "Infinity", "9223372036854775808", "9223372036854775807", "9223372036854775806", "-9223372036854775807", "１２"] {
            XCTAssertThrowsError(try PetLegacyLPSDocument.storedFloat(raw),raw)
        }
    }
    func testEncodingAndByteBounds() throws {
        var data=Data([0xef,0xbb,0xbf]);data.append(Data("vpet:|name#萝莉斯🐱:|".utf8))
        XCTAssertEqual(try PetLegacyLPSDocument.parse(data).lines[0].firstField(named:"name")?.info,"萝莉斯🐱")
        XCTAssertThrowsError(try PetLegacyLPSDocument.parse(Data([0xff])))
        XCTAssertThrowsError(try PetLegacyLPSDocument.parse(Data(repeating:32,count:8*1024*1024+1)))
        XCTAssertTrue(try PetLegacyLPSDocument.parse(Data()).lines.isEmpty)
    }
    func testLineAndFieldBounds() throws {
        XCTAssertEqual(try PetLegacyLPSDocument.parse(Data(String(repeating:"v:|\n",count:10000).utf8)).lines.count,10000)
        XCTAssertThrowsError(try PetLegacyLPSDocument.parse(Data(String(repeating:"v:|\n",count:10001).utf8)))
        XCTAssertEqual(try PetLegacyLPSDocument.parse(Data(("v:|"+String(repeating:"f#1:|",count:2000)).utf8)).lines[0].fields.count,2000)
        XCTAssertThrowsError(try PetLegacyLPSDocument.parse(Data(("v:|"+String(repeating:"f#1:|",count:2001)).utf8)))
    }
    func testOrdinalLookupDoesNotMergeCanonicalUnicodeNames() throws {
        let line=try PetLegacyLPSDocument.parse(Data("vpet:|e\u{0301}#first:|é#second:|".utf8)).lines[0]
        XCTAssertEqual(line.firstField(named:"é")?.info,"second")
        XCTAssertEqual(line.firstField(named:"e\u{0301}")?.info,"first")
    }
    func testDecodingReplacementOrderAndUnknownEscape() throws {
        let line=try PetLegacyLPSDocument.parse(Data("v:|f#/stop/equ/tab/n/r/id/com/!/|/unknown/!n:|".utf8)).lines[0]
        XCTAssertEqual(line.fields[0].info,":|=\t\n\r#,/|/unknown/n")
        XCTAssertEqual(line.fields[0].rawInfo,"/stop/equ/tab/n/r/id/com/!/|/unknown/!n")
    }
}
