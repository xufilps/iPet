import XCTest
@testable import PetCore
final class PetLegacyStatisticsPreviewTests:XCTestCase {
    private func preview(_ text:String) throws -> PetLegacyStatisticsPreview {
        PetLegacyStatisticsPreview(document:try PetLegacyLPSDocument.parse(Data(text.utf8)))
    }
    func testOriginalLibraryStorageTypesAndPreciseLongArePreserved() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Tests/Fixtures/legacy-statistics.json"))) as? [String:Any])
        let p=try preview(XCTUnwrap(fixture["input"] as? String))
        XCTAssertEqual(p.records.count,10)
        XCTAssertEqual(p.records.first { $0.sourceField.name=="stat_money" }?.value,.double(1234.5))
        XCTAssertEqual(p.records.first { $0.sourceField.name=="stat_bb_drink" }?.value,.double(1.25))
        XCTAssertEqual(p.records.first { $0.sourceField.name=="stat_buytimes" }?.value,.int32(7))
        XCTAssertEqual(p.records.first { $0.sourceField.name=="stat_work_time" }?.value,.int64(3600))
        XCTAssertEqual(p.records.first { $0.sourceField.name=="eval_longest_session_seconds" }?.value,.int64(9007199254740993))
        XCTAssertNil(p.numericCounters["eval_longest_session_seconds"])
        XCTAssertEqual(p.numericCounters["stat_money"],1234.5)
        for key in ["plugin_bool","plugin_date","plugin_fixed","plugin_text"] {
            XCTAssertNil(p.records.first { $0.sourceField.name==key }?.value)
            XCTAssertTrue(p.issues.contains { $0.path=="statistics."+key && $0.severity == .blocking })
        }
        XCTAssertEqual(p.records.first { $0.sourceField.name=="plugin_text" }?.sourceField.rawInfo,"主/!n人/n:/!|/id")
    }
    func testSourceRegistryAndDynamicNamesKeepTheirOriginalMeaning() throws {
        let p=try preview("statistics:|stat_level#10:|stat_move_length#5:|stat_sleep_time#3600:|eval_work_completion_rate#0.75:|eval_day_20261003#30:|eval_month_202610#60:|eval_study_project_%E5%AD%A6%E4%B9%A0#3:|buy_蛋糕#4:|")
        XCTAssertEqual(p.records.map(\.value),[.int32(10),.int32(5),.int64(3600),.double(0.75),.int64(30),.int64(60),.int32(3),.int32(4)])
        XCTAssertEqual(p.numericCounters["eval_study_project_%E5%AD%A6%E4%B9%A0"],3)
        XCTAssertNil(p.numericCounters["buy_蛋糕"])
        XCTAssertTrue(p.issues.contains { $0.path=="statistics.buy_蛋糕" && $0.severity == .blocking })
    }
    func testNonCanonicalAndLossyConversionsAreRejectedWithoutDefaultingToZero() throws {
        for (key,value) in [("stat_buytimes","1.25"),("stat_buytimes","2147483648"),("stat_total_time","9223372036854775808"),("stat_bb_drink","1,25"),("stat_money","bad"),("stat_money","NaN"),("stat_level","01"),("stat_money","1e309"),("stat_money","1e-999"),("stat_money","-2e-999")] {
            let p=try preview("statistics:|\(key)#\(value):|")
            XCTAssertNil(p.records[0].value,"\(key)=\(value)");XCTAssertTrue(p.numericCounters.isEmpty)
            XCTAssertEqual(p.records[0].sourceField.rawInfo,value)
            XCTAssertTrue(p.issues.contains { $0.severity == .blocking })
        }
    }
    func testActualZeroAndRepresentableSubnormalRemainReadable() throws {
        for raw in ["0", "-0", "0e-999", "5e-324"] {
            let p=try preview("statistics:|stat_money#\(raw):|")
            XCTAssertEqual(p.records[0].value,.double(try XCTUnwrap(Double(raw))))
            XCTAssertNotNil(p.numericCounters["stat_money"])
            XCTAssertTrue(p.issues.isEmpty)
        }
    }
    func testDuplicateKeysAndRootsDoNotSelectAWinner() throws {
        let p=try preview("statistics:|stat_money#1:|stat_money#2:|")
        XCTAssertEqual(p.records.count,2);XCTAssertTrue(p.records.allSatisfy { $0.value == nil });XCTAssertTrue(p.numericCounters.isEmpty)
        let roots=try preview("statistics:|stat_money#1:|\nstatistics:|stat_money#2:|")
        XCTAssertEqual(roots.sourceLines.count,2);XCTAssertEqual(roots.records.count,2)
        XCTAssertTrue(roots.numericCounters.isEmpty);XCTAssertTrue(roots.issues.contains { $0.path=="statistics" && $0.severity == .blocking })
    }
    func testUnknownNamesCaseAndDynamicShapeAreNotGuessed() throws {
        let p=try preview("statistics:|STAT_MONEY#12:|stat_plugin#1:|eval_day_wrong#30:|buy_#2:|eval_work_project_#3:|")
        XCTAssertTrue(p.records.allSatisfy { $0.expectedKind == nil && $0.value == nil });XCTAssertTrue(p.numericCounters.isEmpty)
    }
    func testCounterBoundsAndMissingRootAreExplicit() throws {
        let p=try preview("statistics:|stat_total_time#-9223372036854775808:|stat_money#1e20:|")
        XCTAssertEqual(p.records[0].value,.int64(Int64.min));XCTAssertEqual(p.records[1].value,.double(1e20))
        XCTAssertTrue(p.numericCounters.isEmpty)
        let missing=try preview("vpet:|name#x:|")
        XCTAssertTrue(missing.records.isEmpty);XCTAssertTrue(missing.issues.contains { $0.severity == .warning })
    }
    func testDiagnosticBoundPreservesAllRecordsAndRootPayload() throws {
        let p=try preview("statistics#unknown:|"+(0..<300).map {"unknown\($0)#raw:|"}.joined()+"tail")
        XCTAssertEqual(p.records.count,300);XCTAssertEqual(p.issues.count,200);XCTAssertGreaterThan(p.omittedIssueCount,0)
        XCTAssertEqual(p.sourceLines[0].rawText,"tail");XCTAssertTrue(p.numericCounters.isEmpty)
    }
    func testWholeSavePreviewExposesStatisticsWithoutApplyingThem() throws {
        let source=Data("vpet:|name#x:|\nstatistics:|stat_money#123.5:|".utf8),p=try PetLegacySavePreview(data:source)
        XCTAssertEqual(p.statistics.numericCounters["stat_money"],123.5)
        XCTAssertEqual(p.petState?.money,0);XCTAssertEqual(p.sourceData,source)
        XCTAssertTrue(p.issues.contains { $0.path=="statistics" && $0.severity == .blocking })
    }
}
