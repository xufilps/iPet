import XCTest
import PetCore
@testable import PetRendering
final class PetRaiseTests:XCTestCase {
    var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testThreeDynamicCyclesThenStaticAndDirectRelease() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            var completed=0;scene.onActionFinished={ _ in completed+=1 }
            scene.beginRaise(mood:.normal)
            XCTAssertEqual(scene.requestedGraphID,"raised.dynamic")
            scene.update(0)
            var seen=Set<Int>()
            for step in 1...400 {
                if let cycle=scene.raisedCycles { seen.insert(cycle) }
                scene.update(Double(step)*0.25)
            }
            XCTAssertEqual(seen,Set([0,1,2]));XCTAssertNil(scene.raisedCycles)
            XCTAssertEqual(scene.requestedAction,.raised);XCTAssertEqual(scene.currentPhase,.loop)
            XCTAssertEqual(completed,0)
            scene.finishRaise();XCTAssertEqual(scene.currentPhase,.end)
            scene.update(101)
            for step in 1...80 { scene.update(101+Double(step)*0.25) }
            XCTAssertEqual(completed,1);XCTAssertEqual(scene.requestedAction,.idle)
        }
    }
    func testMotionThresholdAndReleaseDuringDynamic() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.beginRaise(mood:.normal);scene.update(0)
            var time=0.0
            while scene.raisedCycles == 0 && time<10 { time+=0.25;scene.update(time) }
            XCTAssertEqual(scene.raisedCycles,1)
            scene.updateRaiseMotion(distance:20);XCTAssertEqual(scene.raisedCycles,1)
            scene.updateRaiseMotion(distance:21);XCTAssertEqual(scene.raisedCycles,0)
            scene.finishRaise();XCTAssertNil(scene.raisedCycles)
            XCTAssertEqual(scene.requestedGraphID,"raised.static");XCTAssertEqual(scene.currentPhase,.end)
            scene.play(.head,mood:.normal)
            scene.updateRaiseMotion(distance:100)
            XCTAssertEqual(scene.requestedAction,.head)
        }
    }
    func testMissingDynamicFallsBackAndNewActionClearsQueue() async throws {
        let assets=root
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("manifest.json"))) as? [String:Any])
        let clips=try XCTUnwrap(object["clips"] as? [[String:Any]])
        object["clips"]=clips.filter { $0["graphID"] as? String != "raised.dynamic" }
        let missing=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:object))
        let manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let fallback=PetScene(manifest:missing,assetRoot:assets)
            var diagnostics=0;fallback.onDiagnostic={ _ in diagnostics+=1 }
            fallback.beginRaise(mood:.normal)
            XCTAssertEqual(fallback.requestedAction,.raised);XCTAssertNil(fallback.raisedCycles)
            XCTAssertEqual(diagnostics,1)
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.beginRaise(mood:.ill)
            XCTAssertEqual(scene.requestedGraphID,"raised.dynamic")
            scene.playFidget(graphID:"boring",mood:.normal)
            XCTAssertNil(scene.raisedCycles)
            scene.update(0)
            for step in 1...200 { scene.update(Double(step)*0.25) }
            XCTAssertNotEqual(scene.requestedAction,.raised)
        }
    }
    func testHappyDropSelectsBothOriginalEndVariants() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        let end=try XCTUnwrap(manifest.clips.first { $0.action == .raised && $0.mood == .happy && $0.graphID == "raised.static" }?.stages.first { $0.phase == .end })
        XCTAssertEqual(end.variants?.count,1)
        await MainActor.run {
            var paths=Set<String>()
            for seed in 1...20 {
                let scene=PetScene(manifest:manifest,assetRoot:assets,random:SeededPetRandom(seed:UInt64(seed)))
                scene.beginRaise(mood:.happy);scene.finishRaise()
                XCTAssertEqual(scene.currentPhase,.end)
                if let frame=scene.currentFramePath { paths.insert(frame) }
            }
            XCTAssertEqual(paths.count,2)
        }
    }

}
