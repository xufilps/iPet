// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetDiagnosticsTests:XCTestCase {
    func testBoundedLogCoalescesOnlyConsecutiveMatchesAndKeepsTimes() {
        var log=PetDiagnostics()
        log.record(.rendering,"missing",at:Date(timeIntervalSince1970:1))
        log.record(.rendering,"missing",at:Date(timeIntervalSince1970:2))
        XCTAssertEqual(log.entries.count,1);XCTAssertEqual(log.entries[0].count,2)
        XCTAssertEqual(log.entries[0].first,Date(timeIntervalSince1970:1));XCTAssertEqual(log.entries[0].last,Date(timeIntervalSince1970:2))
        log.record(.save,"missing",at:Date());XCTAssertEqual(log.entries.count,2)
        for index in 0..<201 { log.record(.rendering,String(index),at:Date()) }
        XCTAssertEqual(log.entries.count,200);XCTAssertEqual(log.entries.first?.text,"1")
        log.record(.save,String(repeating:"x",count:501),at:Date())
        XCTAssertEqual(log.entries.last?.text.count,500)
        log.clear();XCTAssertTrue(log.entries.isEmpty)
    }
    func testExportWritesExactlyPreviewAndProtectsSaveDirectoryAndSymlinks() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let save=root.appendingPathComponent("saves"),output=root.appendingPathComponent("report.txt")
        try FileManager.default.createDirectory(at:save,withIntermediateDirectories:true)
        let primary=save.appendingPathComponent("pet.json");try Data("original".utf8).write(to:primary)
        try PetDiagnosticReport.writePreview("preview\n",to:output,protectedDirectory:save)
        XCTAssertEqual(try String(contentsOf:output,encoding:.utf8),"preview\n")
        XCTAssertThrowsError(try PetDiagnosticReport.writePreview("report",to:primary,protectedDirectory:save))
        XCTAssertEqual(try String(contentsOf:primary,encoding:.utf8),"original")
        let link=root.appendingPathComponent("alias.txt")
        try FileManager.default.createSymbolicLink(at:link,withDestinationURL:primary)
        XCTAssertThrowsError(try PetDiagnosticReport.writePreview("report",to:link,protectedDirectory:save))
        XCTAssertEqual(try String(contentsOf:primary,encoding:.utf8),"original")
        XCTAssertThrowsError(try PetDiagnosticReport.writePreview("report",to:save,protectedDirectory:save))
        XCTAssertThrowsError(try PetDiagnosticReport.writePreview("report",to:root,protectedDirectory:save))
        XCTAssertEqual(try String(contentsOf:primary,encoding:.utf8),"original")
    }
    func testDefaultReportOmitsRawLogsAndOptionalExportMatchesPreview() throws {
        var log=PetDiagnostics();log.record(.save,"/Users/private/pet.json: named pet",at:Date(timeIntervalSince1970:1))
        let report=PetDiagnosticReport(appVersion:"0.2.0",systemVersion:"macOS test",clips:147,frames:4248,items:118,simulationEnabled:true,visible:true,writable:false,saveFailed:true)
        let text=try report.text(log:log,description:"Cannot save",includeLogs:false,at:Date(timeIntervalSince1970:0))
        XCTAssertTrue(text.contains("Cannot save"));XCTAssertTrue(text.contains("save: 1"));XCTAssertFalse(text.contains("/Users/private"));XCTAssertFalse(text.contains("named pet"))
        let included=try report.text(log:log,description:"",includeLogs:true,at:Date(timeIntervalSince1970:0))
        XCTAssertTrue(included.contains("/Users/private/pet.json"));XCTAssertTrue(included.contains("1970-01-01"))
        XCTAssertThrowsError(try report.text(log:log,description:String(repeating:"x",count:10001),includeLogs:false,at:Date()))
        XCTAssertEqual(try report.text(log:log,description:"Cannot save",includeLogs:false,at:Date(timeIntervalSince1970:0)),text)
    }
}
