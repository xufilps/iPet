import XCTest
import PetCore
@testable import PetRendering
final class PetPinchRenderingTests:XCTestCase {
    var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testPinchAreaAndHeldLoopRelease() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        let clip=try XCTUnwrap(manifest.clips.first { $0.action == .pinch && $0.mood == .normal })
        XCTAssertEqual(clip.stages.map(\.phase),[.start,.loop,.end])
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            XCTAssertTrue(scene.canPinch(at:CGPoint(x:160,y:350),mood:.normal))
            XCTAssertFalse(scene.canPinch(at:CGPoint(x:210,y:350),mood:.normal))
            var held=true,calls=0,completed=0
            scene.onPinchLoop={ calls+=1;return held }
            scene.onActionFinished={ if $0 == .pinch { completed+=1 } }
            scene.play(.pinch,mood:.normal);scene.update(0)
            var time=0.0
            while calls<2 && time<20 { time+=0.25;scene.update(time) }
            XCTAssertEqual(calls,2);XCTAssertEqual(scene.requestedAction,.pinch)
            held=false;scene.finishAction()
            for _ in 0..<80 { time+=0.25;scene.update(time) }
            XCTAssertEqual(completed,1);XCTAssertEqual(scene.requestedAction,.idle)
            let settled=calls
            scene.play(.head,mood:.normal)
            for _ in 0..<80 { time+=0.25;scene.update(time) }
            XCTAssertEqual(calls,settled)
        }
    }
    func testUnavailableMoodAndDecodeFailureDoNotLeaveHeldLoop() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            XCTAssertFalse(scene.canPinch(at:CGPoint(x:160,y:350),mood:.ill))
            let broken=PetScene(manifest:manifest,assetRoot:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
            var finished=0
            broken.onActionFinished={ if $0 == .pinch { finished+=1 } }
            broken.play(.pinch,mood:.normal)
            XCTAssertEqual(broken.requestedAction,.idle);XCTAssertEqual(finished,1)
            var calls=0;scene.onPinchLoop={ calls+=1;return true }
            scene.play(.pinch,mood:.normal);scene.playFidget(graphID:"boring",mood:.normal)
            scene.update(0)
            for step in 1...200 { scene.update(Double(step)*0.25) }
            XCTAssertEqual(calls,0)
        }
    }

}
