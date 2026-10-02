import XCTest
@testable import PetCore
final class PetSaveManagementTests:XCTestCase {
    func makeStore() throws -> PetSaveStore {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:directory) }
        return PetSaveStore(directory:directory)
    }
    func testPreviewIsReadOnlyAndRestorePreservesLatestAndSource() throws {
        let store=try makeStore();var current=PetState();current.money=120;try store.save(current)
        let original=try Data(contentsOf:store.primary)
        var imported=PetState();imported.name="备份";imported.inventory["unknown"]=2;imported.activity=ActivitySession(activityID:"unknown")
        let data=try store.exportSnapshot(imported)
        XCTAssertTrue(try store.previewImport(data).activity?.isPaused == true)
        XCTAssertEqual(try Data(contentsOf:store.primary),original)
        current.money=140
        let restored=try store.restore(data,currentState:current)
        XCTAssertEqual(restored.name,"备份");XCTAssertEqual(restored.inventory["unknown"],2);XCTAssertTrue(restored.activity?.isPaused == true)
        let files=try FileManager.default.contentsOfDirectory(at:store.directory,includingPropertiesForKeys:nil)
        let checkpoint=try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("pet.before-restore-") })
        XCTAssertEqual(try store.previewImport(Data(contentsOf:checkpoint)).money,140)
        let source=try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("pet.import-source-") })
        XCTAssertEqual(try Data(contentsOf:source),data)
        XCTAssertEqual(try store.load(),restored)
    }
    func testFutureAndInvalidImportsAndProtectedCurrentAreUntouched() throws {
        let store=try makeStore();let current=PetState();try store.save(current)
        let original=try Data(contentsOf:store.primary),future=Data("{\"version\":99}".utf8)
        XCTAssertThrowsError(try store.restore(future,currentState:current))
        XCTAssertThrowsError(try store.previewImport(Data("bad".utf8)))
        XCTAssertEqual(try Data(contentsOf:store.primary),original)
        try future.write(to:store.primary)
        XCTAssertThrowsError(try store.restore(original,currentState:current))
        XCTAssertEqual(try Data(contentsOf:store.primary),future)
    }
    func testLegacyImportPreservesBytesAndWriteFailureRejects() throws {
        let store=try makeStore(),current=PetState()
        let apple=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let legacy=try Data(contentsOf:apple.appendingPathComponent("Tests/Fixtures/pet-v1.json"))
        let restored=try store.restore(legacy,currentState:current)
        XCTAssertEqual(restored.name,"原生旧档");XCTAssertEqual(restored.money,1000)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),legacy)
        let blocked=try makeStore();try FileManager.default.removeItem(at:blocked.directory)
        let sentinel=Data("blocked".utf8);try sentinel.write(to:blocked.directory)
        XCTAssertThrowsError(try blocked.restore(legacy,currentState:current))
        XCTAssertEqual(try Data(contentsOf:blocked.directory),sentinel)
        XCTAssertThrowsError(try blocked.previewImport(Data(repeating:0,count:PetSaveStore.snapshotSizeLimit+1)))
    }

}
