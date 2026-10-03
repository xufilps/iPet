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
    func testUnknownInventoryRemainsVisibleAndCannotBeUsed() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        var state=PetEngine().state;state.inventory=["unresolved.item":4]
        try PetSaveStore(directory:directory).save(state)
        let model=IOSPetModel(directory:directory,defaults:defaults)
        XCTAssertTrue(model.ready)
        XCTAssertEqual(model.unknownInventoryIDs,["unresolved.item"])
        model.setActive(true);model.perform(.useItem("unresolved.item"));model.setActive(false)
        XCTAssertEqual(model.state.inventory["unresolved.item"],4)
        XCTAssertEqual(try PetSaveStore(directory:directory).load()?.inventory["unresolved.item"],4)
    }

    func testApplicationHostIsIsolatedFromOrdinarySave() async throws {
        XCTAssertEqual(ProcessInfo.processInfo.environment["IPET_TEST_HOST"],"1")
        let ordinary=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:false).appendingPathComponent("iPet/pet.json")
        let before=try? Data(contentsOf:ordinary)
        let model=IOSPetModel.application()
        let host=try XCTUnwrap(model.saveDirectory)
        guard host.deletingLastPathComponent().standardizedFileURL == FileManager.default.temporaryDirectory.standardizedFileURL,
              host.lastPathComponent.hasPrefix("iPet-host-"),!model.automaticDialogue else {
            XCTFail("Test factory must be isolated before issuing any command");return
        }
        defer {
            try? FileManager.default.removeItem(at:host)
            UserDefaults.standard.removePersistentDomain(forName:host.lastPathComponent)
        }
        XCTAssertTrue(model.ready)
        model.setActive(true);model.interact(.feed);model.setActive(false)
        XCTAssertEqual(try? Data(contentsOf:ordinary),before)
    }
    func testCorruptPrimaryRecoversBackupAndRetainsOriginal() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let store=PetSaveStore(directory:directory)
        var state=PetEngine().state;state.money=42;try store.save(state)
        state.money=52;try store.save(state)
        let damaged=Data("broken json".utf8);try damaged.write(to:store.primary)
        let model=IOSPetModel(directory:directory,defaults:defaults)
        XCTAssertTrue(model.ready);XCTAssertEqual(model.state.money,42)
        XCTAssertTrue(model.message.contains("备份"))
        let original=try XCTUnwrap(FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil).first { $0.lastPathComponent.hasPrefix("pet.corrupt-") })
        XCTAssertEqual(try Data(contentsOf:original),damaged)
        model.setActive(true);model.save();model.setActive(false)
        XCTAssertEqual(try Data(contentsOf:original),damaged)
    }
    func testRelaunchKeepsActivityPausedUntilExplicitResume() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let clock=IOSClock(),first=IOSPetModel(directory:directory,defaults:defaults,clock:clock)
        first.setActive(true)
        let work=try XCTUnwrap(first.catalog.activities.first { $0.levelLimit<=first.state.level })
        first.perform(.startActivity(work.id));clock.now=15;first.tick();first.setActive(false)
        let elapsed=try XCTUnwrap(first.state.activity?.elapsedSeconds),money=first.state.money
        clock.now=3600
        let reopened=IOSPetModel(directory:directory,defaults:defaults,clock:clock)
        XCTAssertTrue(reopened.state.activity?.isPaused == true)
        reopened.setActive(true);clock.now += 15;reopened.tick()
        XCTAssertEqual(reopened.state.activity?.elapsedSeconds,elapsed);XCTAssertEqual(reopened.state.money,money)
        reopened.perform(.resumeActivity);clock.now += 15;reopened.tick()
        XCTAssertEqual(reopened.state.activity?.elapsedSeconds,elapsed+15)
        reopened.setActive(false)
    }
    func testTransientCareReturnsToActivityAndHidingStageClosesSpeech() async throws {
        let (directory,defaults)=try fixture();defer { try? FileManager.default.removeItem(at:directory) }
        let clock=IOSClock(),model=IOSPetModel(directory:directory,defaults:defaults,clock:clock)
        model.setActive(true)
        let work=try XCTUnwrap(model.catalog.activities.first { $0.levelLimit<=model.state.level })
        model.perform(.startActivity(work.id));model.interact(.feed)
        XCTAssertEqual(model.scene?.requestedAction,.eat)
        for index in 0..<200 { model.scene?.update(Double(index)*0.15) }
        XCTAssertEqual(model.state.activity?.activityID,work.id)
        XCTAssertEqual(model.scene?.requestedAction,.activity)
        XCTAssertEqual(model.scene?.requestedGraphID,work.graphID)
        model.perform(.pauseActivity)
        let before=model.state;model.showPreview();clock.now=1;model.tick()
        XCTAssertFalse(model.speechText.isEmpty);model.setStageVisible(false)
        XCTAssertTrue(model.speechText.isEmpty);clock.now=2;model.tick()
        XCTAssertEqual(model.state,before);model.setActive(false)
    }

}
