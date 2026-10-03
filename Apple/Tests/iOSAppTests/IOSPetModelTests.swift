// SPDX-License-Identifier: Apache-2.0
import XCTest
import Foundation
import PetCore
@testable import iPet_iOS

private final class IOSClock:PetClock { var now=0.0 }
@MainActor final class IOSPetModelTests:XCTestCase {
    private func fixture() throws -> (URL,UserDefaults) {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("iPet-test-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let suite="iPet-test-"+UUID().uuidString
        return (directory,UserDefaults(suiteName:suite)!)
    }
    func testFutureSaveIsPreservedAndNeverWritten() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let bytes=Data("{\"version\":100}".utf8)
        let path=directory.appendingPathComponent("pet.json");try bytes.write(to:path)
        let model=IOSPetModel(directory:directory,defaults:defaults)
        XCTAssertNotNil(model.startupError);XCTAssertFalse(model.ready)
        model.setActive(true);model.interact(.feed);model.save()
        XCTAssertEqual(try Data(contentsOf:path),bytes)
    }
    func testMissingResourcesDoesNotCreateSave() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let model=IOSPetModel(root:directory.appendingPathComponent("missing"),directory:directory,defaults:defaults)
        XCTAssertNotNil(model.startupError);model.save()
        XCTAssertFalse(FileManager.default.fileExists(atPath:directory.appendingPathComponent("pet.json").path))
    }
    func testBuyUseAndSaveRoundTrip() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let model=IOSPetModel(directory:directory,defaults:defaults)
        XCTAssertTrue(model.ready);model.setActive(true)
        let item=try XCTUnwrap(model.catalog.items.first { $0.price<100 && $0.imagePath != nil })
        let money=model.state.money
        model.perform(.buyItem(item.id,mode:.inventory))
        XCTAssertEqual(model.state.inventory[item.id],1)
        XCTAssertEqual(model.state.money,money-item.price,accuracy:0.0001)
        model.perform(.useItem(item.id))
        XCTAssertNil(model.state.inventory[item.id]);XCTAssertTrue(model.scene?.hasFoodImage == true)
        model.setActive(false)
        XCTAssertEqual(try PetSaveStore(directory:directory).load()?.money,model.state.money)
    }
    func testBackgroundDoesNotAdvanceActivityAndActivationIsIdempotent() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let clock=IOSClock(),model=IOSPetModel(directory:directory,defaults:defaults,clock:clock)
        model.setActive(true)
        let work=try XCTUnwrap(model.catalog.activities.first { $0.levelLimit<=model.state.level })
        model.perform(.startActivity(work.id));clock.now=15;model.tick()
        let elapsed=try XCTUnwrap(model.state.activity?.elapsedSeconds)
        model.setActive(false);clock.now=300;model.tick()
        XCTAssertEqual(model.state.activity?.elapsedSeconds,elapsed)
        model.setActive(true);model.setActive(true);clock.now=315;model.tick()
        XCTAssertEqual(model.state.activity?.elapsedSeconds,elapsed+15)
        model.setActive(false)
    }
    func testWriteFailureBlocksFurtherPurchaseAndRetryRecovers() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let model=IOSPetModel(directory:directory,defaults:defaults)
        model.setActive(true)
        try FileManager.default.removeItem(at:directory)
        try Data("blocked".utf8).write(to:directory)
        model.save();XCTAssertFalse(model.saveError.isEmpty)
        let state=model.state
        if let item=model.catalog.items.first { model.perform(.buyItem(item.id,mode:.inventory)) }
        XCTAssertEqual(model.state,state)
        try FileManager.default.removeItem(at:directory);model.save()
        XCTAssertTrue(model.saveError.isEmpty);model.setActive(false)
    }
    func testPreviewAndAppearanceChangesDoNotRewardOrRestart() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let clock=IOSClock(),model=IOSPetModel(directory:directory,defaults:defaults,clock:clock)
        model.setActive(true);let before=model.state;model.showPreview()
        // Drive the shared Say start phase without advancing the rule clock.
        for index in 0..<100 { model.scene?.update(Double(index)*0.15) }
        clock.now=1;model.tick();let text=model.speechText
        XCTAssertFalse(text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
        model.fontSize=24;model.opacity=0.5;model.updateSpeechSettings()
        XCTAssertEqual(model.speechText,text);XCTAssertEqual(model.state,before)
        model.closeSpeech();model.setActive(false)
    }
    func testSaveFailureFreezesRulesAndRetryNeverCatchesUp() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let clock=IOSClock(),model=IOSPetModel(directory:directory,defaults:defaults,clock:clock)
        model.setActive(true)
        let work=try XCTUnwrap(model.catalog.activities.first { $0.levelLimit<=model.state.level })
        model.perform(.startActivity(work.id))
        try FileManager.default.removeItem(at:directory)
        try Data("blocked".utf8).write(to:directory)
        model.save();let frozen=model.state
        for _ in 0..<4 { clock.now += 15;model.tick() }
        XCTAssertEqual(model.state,frozen)
        try FileManager.default.removeItem(at:directory);model.save()
        XCTAssertTrue(model.saveError.isEmpty)
        clock.now += 15;model.tick()
        XCTAssertEqual(model.state.activity?.elapsedSeconds,(frozen.activity?.elapsedSeconds ?? 0)+15)
        model.setActive(false)
    }
    func testSettingsPreviewDoesNotWaitForUnmountedStage() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let clock=IOSClock(),model=IOSPetModel(directory:directory,defaults:defaults,clock:clock)
        model.setActive(true);let before=model.state
        model.showPreview();clock.now=1;model.tick()
        XCTAssertFalse(model.speechText.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(model.state,before)
        model.setActive(false)
    }
}
