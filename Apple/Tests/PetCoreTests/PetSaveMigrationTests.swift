import XCTest
@testable import PetCore
final class PetSaveMigrationTests: XCTestCase {
    func store() throws -> PetSaveStore {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:root) };return PetSaveStore(directory:root)
    }
    func legacy() throws -> Data {
        let apple=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf:apple.appendingPathComponent("Tests/Fixtures/pet-v1.json"))
    }
    func testV1PreservedAndMoneyGrantedOnce() throws {
        let store=try store(), data=try legacy();try data.write(to:store.primary)
        var state=try XCTUnwrap(store.load());XCTAssertEqual(state.name,"原生旧档");XCTAssertEqual(state.strength,87);XCTAssertTrue(state.resting);XCTAssertEqual(state.money,1000)
        state.money=123;try store.save(state)
        let copy=try XCTUnwrap(store.migrationBackupURL);XCTAssertEqual(try Data(contentsOf:copy),data)
        XCTAssertEqual(try store.load()?.money,123)
        let header=try JSONSerialization.jsonObject(with:Data(contentsOf:store.primary)) as! [String:Any]
        XCTAssertEqual(header["version"] as? Int,5)
        try store.save(state);XCTAssertEqual(try Data(contentsOf:copy),data)
    }
    func testFutureBackupAndCatalogNeverOverwrittenDuringMigration() throws {
        let store=try store(), data=try legacy();try data.write(to:store.primary)
        let future=Data("{\"version\":99}".utf8);try future.write(to:store.backup)
        let state=try XCTUnwrap(store.load());XCTAssertThrowsError(try store.save(state))
        XCTAssertEqual(try Data(contentsOf:store.primary),data);XCTAssertEqual(try Data(contentsOf:store.backup),future)
        let other=try self.store();var unknown=PetState();unknown.catalogVersion=99
        let document=PetSaveDocument(state:unknown);let bytes=try JSONEncoder().encode(document);try bytes.write(to:other.primary)
        XCTAssertThrowsError(try other.load());XCTAssertEqual(try Data(contentsOf:other.primary),bytes)
    }
    func testLegacyNegativeStoreRejectedV2AcceptsAndUnknownDataSurvives() throws {
        var object=try JSONSerialization.jsonObject(with:legacy()) as! [String:Any]
        var values=object["state"] as! [String:Any];values["storedStrength"] = -50;object["state"]=values
        XCTAssertThrowsError(try PetSaveMigration.decodeLegacy(JSONSerialization.data(withJSONObject:object)))
        let store=try store();var state=PetState();state.storedStrength = -50;state.money = -8;state.inventory["unknown"]=3
        var session=ActivitySession(activityID:"unknown");session.earned=1;state.activity=session
        try store.save(state);let loaded=try XCTUnwrap(store.load());XCTAssertEqual(loaded.inventory["unknown"],3);XCTAssertEqual(loaded.storedStrength,-50);XCTAssertTrue(loaded.activity?.isPaused == true)
        let engine=PetEngine(state:loaded);XCTAssertFalse(engine.perform(.resumeActivity).accepted);XCTAssertTrue(engine.perform(.stopActivity).accepted);XCTAssertEqual(engine.state.money,-8)
    }
    func testRecoverLegacyBackupAndBackupCreationFailurePreservesSource() throws {
        let store=try store(), data=try legacy();try data.write(to:store.backup);try Data("broken".utf8).write(to:store.primary)
        let loaded=try XCTUnwrap(store.load());try store.save(loaded)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),data)
        let blocked=try self.store();try data.write(to:blocked.primary);let state=try XCTUnwrap(blocked.load())
        // Turn the destination into a regular file after load; no write or backup can succeed.
        let held=blocked.directory.appendingPathExtension("held");try FileManager.default.moveItem(at:blocked.directory,to:held)
        defer { try? FileManager.default.removeItem(at:held) }
        try Data().write(to:blocked.directory)
        XCTAssertThrowsError(try blocked.save(state));XCTAssertEqual(try Data(contentsOf:held.appendingPathComponent("pet.json")),data)
    }
}
