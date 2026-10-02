import XCTest
import PetCore
@testable import PetRendering
final class PetSideHideTests:XCTestCase {
    func testStrictThresholdAndOriginalAnchors() throws {
        let screen=CGRect(x:-1000,y:50,width:1000,height:900)
        XCTAssertNil(PetSideHidePlan.make(pet:CGRect(x:-1025,y:300,width:250,height:250),screen:screen))
        let left=try XCTUnwrap(PetSideHidePlan.make(pet:CGRect(x:-1026,y:300,width:250,height:250),screen:screen))
        XCTAssertEqual(left.graphID,"sidehide.left")
        XCTAssertEqual(left.located(pet:CGRect(x:-1026,y:300,width:250,height:250),screen:screen).minX,-1109.5)
        let right=try XCTUnwrap(PetSideHidePlan.make(pet:CGRect(x:-224,y:300,width:250,height:250),screen:screen))
        XCTAssertEqual(right.graphID,"sidehide.right")
        XCTAssertEqual(right.located(pet:CGRect(x:-224,y:900,width:250,height:250),screen:screen),CGRect(x:-140.5,y:700,width:250,height:250))
    }
    func testOffscreenAndInvalidFramesCannotEnter() {
        let screen=CGRect(x:0,y:0,width:1000,height:800)
        XCTAssertNil(PetSideHidePlan.make(pet:CGRect(x:-300,y:100,width:250,height:250),screen:screen))
        XCTAssertNil(PetSideHidePlan.make(pet:CGRect(x:-30,y:900,width:250,height:250),screen:screen))
        XCTAssertNil(PetSideHidePlan.make(pet:.zero,screen:screen))
        XCTAssertNil(PetSideHidePlan.make(pet:CGRect(x:0,y:0,width:250,height:250),screen:.zero))
    }
    func testSideHideLoopsAndClickStartsEndDirectly() async throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets")
        let manifest=try PetManifest.load(from:root)
        for graph in ["sidehide.left","sidehide.right"] {
            let clip=try XCTUnwrap(manifest.clips.first { $0.graphID==graph && $0.mood == .normal })
            XCTAssertEqual(clip.stages.map(\.phase),[.start,.loop,.end])
            await MainActor.run {
                let scene=PetScene(manifest:manifest,assetRoot:root)
                XCTAssertTrue(scene.playSideHide(graphID:graph,mood:.normal))
                scene.update(0)
                for step in 1...80 { scene.update(Double(step)*0.25) }
                XCTAssertEqual(scene.requestedAction,.sideHide);XCTAssertEqual(scene.currentPhase,.loop)
                XCTAssertFalse(scene.isMovementAnimation)
                scene.finishSideHide();XCTAssertEqual(scene.currentPhase,.end)
                var completed=false
                scene.onActionFinished={ if $0 == .sideHide { completed=true } }
                for step in 1...40 { scene.update(20+Double(step)*0.25) }
                XCTAssertTrue(completed);XCTAssertEqual(scene.requestedAction,.idle)
                XCTAssertFalse(scene.playSideHide(graphID:"sidehide.absent",mood:.normal))
                XCTAssertEqual(scene.requestedAction,.idle)
            }
        }
    }
    func testDecodeFailureNotifiesOwnerAndEarlyClickCanBeInterrupted() async throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets")
        let manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let broken=PetScene(manifest:manifest,assetRoot:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
            var callbacks=0
            broken.onActionFinished={ if $0 == .sideHide { callbacks+=1 } }
            XCTAssertFalse(broken.playSideHide(graphID:"sidehide.right",mood:.normal))
            XCTAssertEqual(callbacks,1);XCTAssertEqual(broken.requestedAction,.idle)
            let scene=PetScene(manifest:manifest,assetRoot:root)
            XCTAssertTrue(scene.playSideHide(graphID:"sidehide.left",mood:.ill))
            XCTAssertEqual(scene.currentPhase,.start)
            scene.finishSideHide();XCTAssertEqual(scene.currentPhase,.end)
            scene.play(.head,mood:.normal)
            var oldCompletion=false
            scene.onActionFinished={ if $0 == .sideHide { oldCompletion=true } }
            scene.update(0)
            for step in 1...80 { scene.update(Double(step)*0.25) }
            XCTAssertFalse(oldCompletion);XCTAssertNil(scene.requestedGraphID)
        }
    }

    func testHoverReturnsToMainLoopAndClickUsesMainEnd() async throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets")
        let manifest=try PetManifest.load(from:root)
        for side in ["left","right"] {
            XCTAssertNotNil(manifest.clips.first { $0.graphID == "sidehide."+side+".rise" && $0.mood == .normal })
            await MainActor.run {
                let scene=PetScene(manifest:manifest,assetRoot:root)
                XCTAssertTrue(scene.playSideHide(graphID:"sidehide."+side,mood:.normal))
                scene.setSideHideHovered(true)
                XCTAssertEqual(scene.requestedGraphID,"sidehide."+side+".rise")
                XCTAssertEqual(scene.currentPhase,.start)
                scene.setSideHideHovered(false);XCTAssertEqual(scene.currentPhase,.end)
                scene.setSideHideHovered(true);XCTAssertEqual(scene.currentPhase,.start)
                scene.setSideHideHovered(false)
                scene.update(0)
                for step in 1...80 { scene.update(Double(step)*0.25) }
                XCTAssertEqual(scene.requestedGraphID,"sidehide."+side);XCTAssertEqual(scene.currentPhase,.loop)
                scene.setSideHideHovered(true)
                scene.finishSideHide()
                XCTAssertEqual(scene.requestedGraphID,"sidehide."+side);XCTAssertEqual(scene.currentPhase,.end)
                scene.setSideHideHovered(true)
                XCTAssertEqual(scene.requestedGraphID,"sidehide."+side)
                scene.play(.head,mood:.normal);scene.setSideHideHovered(true)
                XCTAssertEqual(scene.requestedAction,.head)
                XCTAssertTrue(scene.playSideHide(graphID:"sidehide."+side,mood:.normal))
                scene.setSideHideHovered(true);scene.setSideHideHovered(false)
                scene.playFidget(graphID:"boring",mood:.normal)
                scene.update(50)
                for step in 1...160 { scene.update(50+Double(step)*0.25) }
                XCTAssertNotEqual(scene.requestedAction,.sideHide)
                XCTAssertNotEqual(scene.requestedGraphID,"sidehide."+side)
                scene.finishAction()
                for step in 1...80 { scene.update(90+Double(step)*0.25) }
                XCTAssertNil(scene.requestedGraphID)
            }
        }
    }

    func testMissingRiseKeepsMainAndReportsDiagnostic() async throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets")
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("manifest.json"))) as? [String:Any])
        let clips=try XCTUnwrap(object["clips"] as? [[String:Any]])
        object["clips"]=clips.filter { $0["graphID"] as? String != "sidehide.left.rise" }
        let manifest=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:object))
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:root)
            var diagnostics=0;scene.onDiagnostic={ _ in diagnostics+=1 }
            XCTAssertTrue(scene.playSideHide(graphID:"sidehide.left",mood:.normal))
            scene.setSideHideHovered(true)
            XCTAssertEqual(scene.requestedGraphID,"sidehide.left")
            XCTAssertEqual(scene.requestedAction,.sideHide);XCTAssertEqual(diagnostics,1)
            scene.finishSideHide();XCTAssertEqual(scene.currentPhase,.end)
        }
    }

}
