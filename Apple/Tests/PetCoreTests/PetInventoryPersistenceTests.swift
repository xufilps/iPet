import XCTest
@testable import PetCore
final class PetInventoryPersistenceTests:XCTestCase {
    private func store() throws -> PetSaveStore {
        let path=FileManager.default.temporaryDirectory.appendingPathComponent("ipet-inventory-\(UUID())")
        try FileManager.default.createDirectory(at:path,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:path) }
        return PetSaveStore(directory:path)
    }
    private func state() throws -> PetState {
        var state=PetState();state.inventory["owned"]=2
        let doc=try PetLegacyLPSDocument.parse(Data("item0:|name#旧物品:|itemtype#Food:|Type#Drink:|Price#5:|StrengthDrink#12:|Data#custom:|Star#True:|".utf8))
        state.inventoryMetadata=["owned":try PetInventoryMetadata(legacy:XCTUnwrap(PetLegacyInventoryPreview(document:doc).records[0].item))]
        return state
    }
    func testMetadataRoundTripUsesV9AndSingleQuantity() throws {
        let store=try store(),state=try state();try store.save(state)
        let loaded=try XCTUnwrap(store.load());XCTAssertEqual(loaded,state)
        XCTAssertEqual(PetSaveDocument(state:loaded).version,9)
        XCTAssertEqual(loaded.inventory["owned"],2);XCTAssertEqual(loaded.inventoryMetadata?["owned"]?.data,"custom")
        XCTAssertEqual(try store.previewImport(store.exportSnapshot(state)),state)
    }
    func testV8LoadsUnchangedAndPreservesOriginalBeforeFirstV9Write() throws {
        let store=try store();var state=PetState();state.inventory["old"]=7;state.money=22
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:store.exportSnapshot(state)) as? [String:Any]);object["version"]=8
        let bytes=try JSONSerialization.data(withJSONObject:object,options:.sortedKeys);try bytes.write(to:store.primary)
        let loaded=try XCTUnwrap(store.load());XCTAssertEqual(loaded,state);XCTAssertEqual(try Data(contentsOf:store.primary),bytes)
        try store.save(loaded);let original=try XCTUnwrap(store.migrationBackupURL)
        XCTAssertTrue(original.lastPathComponent.hasPrefix("pet.v8-before-upgrade-"));XCTAssertEqual(try Data(contentsOf:original),bytes)
        XCTAssertEqual(try store.load(),state)
    }
    func testV8CannotCarryNewMetadataAndV9RequiresGrowth() throws {
        let store=try store(),state=try state()
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:store.exportSnapshot(state)) as? [String:Any]);object["version"]=8
        XCTAssertThrowsError(try store.previewImport(JSONSerialization.data(withJSONObject:object)))
        object["version"]=9;var values=try XCTUnwrap(object["state"] as? [String:Any]);values.removeValue(forKey:"growth");object["state"]=values
        XCTAssertThrowsError(try store.previewImport(JSONSerialization.data(withJSONObject:object)))
    }
    func testFutureNestedHeaderProtectsPrimaryEvenWhenPayloadIncomplete() throws {
        let store=try store(),bytes=Data(#"{"version":9,"state":{"inventoryMetadata":{"owned":{"version":2}}}}"#.utf8)
        try bytes.write(to:store.primary)
        for action in [{ _=try store.load() },{ try store.save(PetState()) },{ _=try store.previewImport(bytes) }] {
            XCTAssertThrowsError(try action()) { guard case PetSaveError.unsupportedInventoryVersion(2) = $0 else { return XCTFail("Unexpected \($0)") } }
            XCTAssertEqual(try Data(contentsOf:store.primary),bytes)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:store.directory.path),["pet.json"])
    }
    func testFutureNestedBackupBlocksSaveAndRestoreWithoutChangingFiles() throws {
        let store=try store();try store.save(PetState());let primary=try Data(contentsOf:store.primary)
        let bytes=Data(#"{"version":9,"state":{"inventoryMetadata":{"owned":{"version":7}}}}"#.utf8);try bytes.write(to:store.backup)
        XCTAssertThrowsError(try store.save(PetState()))
        XCTAssertThrowsError(try store.restore(primary,currentState:PetState()))
        XCTAssertEqual(try Data(contentsOf:store.primary),primary);XCTAssertEqual(try Data(contentsOf:store.backup),bytes)
    }
    func testFutureRootVersion10IsProtected() throws {
        let store=try store(),bytes=Data(#"{"version":10}"#.utf8);try bytes.write(to:store.primary)
        XCTAssertThrowsError(try store.load()) { guard case PetSaveError.unsupportedVersion(10) = $0 else { return XCTFail("Unexpected \($0)") } }
        XCTAssertThrowsError(try store.save(PetState()));XCTAssertEqual(try Data(contentsOf:store.primary),bytes)
    }
    func testMetadataValidationRejectsOrphansAndInvalidIDs() throws {
        var state=try state();state.inventory.removeValue(forKey:"owned");XCTAssertThrowsError(try state.validate())
        state=try self.state();state.inventoryMetadata?["owned"]?.price = .infinity;XCTAssertThrowsError(try state.validate())
    }
    func testOversizedMetadataSaveDoesNotAlterPrimaryOrBackup() throws {
        let store=try store();try store.save(PetState());try store.save(PetState())
        let primary=try Data(contentsOf:store.primary),backup=try Data(contentsOf:store.backup)
        var large=try state();var item=try XCTUnwrap(large.inventoryMetadata?["owned"])
        item.data=String(repeating:"x",count:7*1024*1024)
        for id in ["a","b","c"] { large.inventory[id]=1;large.inventoryMetadata?[id]=item }
        XCTAssertThrowsError(try store.save(large)) { guard case PetSaveError.snapshotTooLarge = $0 else { return XCTFail("Unexpected \($0)") } }
        XCTAssertEqual(try Data(contentsOf:store.primary),primary);XCTAssertEqual(try Data(contentsOf:store.backup),backup)
    }
    func testFutureMetadataWinsOverMalformedSiblingPayload() throws {
        let store=try store(),bytes=Data(#"{"version":9,"state":{"inventoryMetadata":{"bad":{"noVersion":true},"future":{"version":3}}}}"#.utf8)
        try bytes.write(to:store.primary)
        XCTAssertThrowsError(try store.load()) { guard case PetSaveError.unsupportedInventoryVersion(3) = $0 else { return XCTFail("Unexpected \($0)") } }
        XCTAssertEqual(try Data(contentsOf:store.primary),bytes)
    }
    func testRestoreRejectsOutputExpansionBeforeAnyFileMutation() throws {
        let store=try store();try store.save(PetState());var latest=PetState();latest.money=80;try store.save(latest)
        var imported=try state();var metadata=try XCTUnwrap(imported.inventoryMetadata?["owned"])
        metadata.data=String(repeating:"/",count:3*1024*1024)
        for id in ["a","b","c"] { imported.inventory[id]=1;imported.inventoryMetadata?[id]=metadata }
        let compactEncoder=JSONEncoder();compactEncoder.outputFormatting=[.withoutEscapingSlashes]
        let compact=try compactEncoder.encode(PetSaveDocument(state:imported))
        XCTAssertLessThan(compact.count,PetSaveStore.snapshotSizeLimit)
        XCTAssertNoThrow(try store.previewImport(compact))
        let paths=try FileManager.default.contentsOfDirectory(at:store.directory,includingPropertiesForKeys:nil)
        let before=try Dictionary(uniqueKeysWithValues:paths.map { ($0.lastPathComponent,try Data(contentsOf:$0)) })
        XCTAssertThrowsError(try store.restore(compact,currentState:latest)) { guard case PetSaveError.snapshotTooLarge = $0 else { return XCTFail("Unexpected \($0)") } }
        let afterPaths=try FileManager.default.contentsOfDirectory(at:store.directory,includingPropertiesForKeys:nil)
        let after=try Dictionary(uniqueKeysWithValues:afterPaths.map { ($0.lastPathComponent,try Data(contentsOf:$0)) })
        XCTAssertEqual(Set(before.keys),Set(after.keys))
        for (name,bytes) in before { XCTAssertEqual(after[name],bytes,name) }
    }
    func testV8RestorePreservesSourceAndCurrentBeforeV9Publish() throws {
        let store=try store();var old=PetState();old.money=33
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:store.exportSnapshot(old)) as? [String:Any]);object["version"]=8
        let source=try JSONSerialization.data(withJSONObject:object);let imported=try store.restore(source,currentState:state())
        XCTAssertEqual(imported.money,33);XCTAssertNil(imported.inventoryMetadata)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationBackupURL)),source)
        let checkpoint=try store.previewImport(Data(contentsOf:XCTUnwrap(store.lastRestoreBackupURL)))
        XCTAssertEqual(checkpoint.inventoryMetadata?["owned"]?.data,"custom")
        XCTAssertEqual(try store.load(),imported)
    }
}
