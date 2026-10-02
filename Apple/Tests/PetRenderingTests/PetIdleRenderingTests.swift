import XCTest
import PetCore
@testable import PetRendering
private struct IdleHighRandom:PetRandom { mutating func unit()->Double { 1.0.nextDown } }
final class PetIdleRenderingTests:XCTestCase {
    var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testSourcePoolDefaultsSinglesAndAdjacentMoodFallback() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        XCTAssertNotNil(manifest.clips.first { $0.graphID == "bubbles" && $0.mood == .normal })
        XCTAssertNil(manifest.clips.first { $0.graphID == "amusement_b" })
        XCTAssertNil(manifest.clips.first { $0.graphID == "meow" }?.idleLoopLimit)
        XCTAssertEqual(manifest.fidgetCandidates(mood:.happy).count,9)
        XCTAssertTrue(manifest.fidgetCandidates(mood:.ill).isEmpty)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.playFidget(graphID:"squat",mood:.happy)
            scene.update(0)
            var time=0.0
            while scene.currentPhase == .start && time<10 { time+=0.25;scene.update(time) }
            XCTAssertEqual(scene.currentPhase,.loop);XCTAssertEqual(scene.requestedAction,.fidget)
            scene.finishAction()
            for _ in 0..<100 { time+=0.25;scene.update(time) }
            XCTAssertEqual(scene.requestedAction,.idle)
            XCTAssertFalse(scene.playRandomFidget(mood:.ill))
            XCTAssertTrue(scene.playRandomFidget(mood:.normal))
        }
    }
    func testProbabilityExitAndSingleCompletion() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets,random:IdleHighRandom())
            var finished=0;scene.onActionFinished={ if $0 == .fidget { finished+=1 } }
            scene.playFidget(graphID:"boring",mood:.normal);scene.update(0)
            for step in 1...1000 { scene.update(Double(step)*0.25) }
            XCTAssertEqual(finished,1);XCTAssertEqual(scene.requestedAction,.idle)
            scene.playFidget(graphID:"meow",mood:.normal);scene.update(251)
            for step in 1...100 { scene.update(251+Double(step)*0.25) }
            XCTAssertEqual(finished,2);XCTAssertEqual(scene.requestedAction,.idle)
        }
    }
}
