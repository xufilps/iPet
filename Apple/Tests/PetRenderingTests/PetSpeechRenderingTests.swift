import XCTest
import PetCore
@testable import PetRendering
final class PetSpeechRenderingTests:XCTestCase {
    var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testFourExpressionsStartReadyOnceLoopThenEnd() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            var families=Set<String>()
            for seed in 1...24 {
                let scene=PetScene(manifest:manifest,assetRoot:assets,random:SeededPetRandom(seed:UInt64(seed)))
                var ready=0,finished=0
                scene.onActionFinished={ _ in finished+=1 }
                XCTAssertTrue(scene.playSpeech(mood:.normal) { ready+=1 })
                families.insert(scene.requestedGraphID ?? "")
                XCTAssertEqual(scene.currentPhase,.start);XCTAssertEqual(ready,0)
                for step in 0...20 { scene.update(Double(step)*0.25) }
                XCTAssertEqual(ready,1);XCTAssertEqual(scene.currentPhase,.loop)
                XCTAssertEqual(finished,0)
                scene.finishSpeech();XCTAssertEqual(scene.currentPhase,.end)
                for step in 21...50 { scene.update(Double(step)*0.25) }
                XCTAssertEqual(scene.requestedAction,.idle);XCTAssertEqual(finished,1)
            }
            XCTAssertEqual(families,Set(["say.self","say.serious","say.shining","say.shy"]))
        }
    }
    func testBusyIllMissingAndInterruptionDoNotDeliverOldReady() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            XCTAssertFalse(scene.playSpeech(mood:.ill) {})
            scene.play(.sleep,mood:.normal)
            XCTAssertFalse(scene.playSpeech(mood:.normal) {});XCTAssertEqual(scene.requestedAction,.sleep)
            scene.play(.idle,mood:.normal)
            var ready=0
            XCTAssertTrue(scene.playSpeech(mood:.normal) { ready+=1 })
            scene.play(.head,mood:.normal)
            for step in 0...30 { scene.update(Double(step)*0.25) }
            XCTAssertEqual(ready,0)
            scene.play(.idle,mood:.normal)
            XCTAssertTrue(scene.playSpeech(mood:.happy) { ready+=1 })
            scene.discardSpeechStart();XCTAssertEqual(scene.currentPhase,.end)
            for step in 31...50 { scene.update(Double(step)*0.25) }
            XCTAssertEqual(ready,0);XCTAssertEqual(scene.requestedAction,.idle)
        }
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("manifest.json"))) as? [String:Any])
        object["clips"]=(object["clips"] as? [[String:Any]])?.filter { $0["action"] as? String != "say" }
        let missing=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:object))
        await MainActor.run {
            let scene=PetScene(manifest:missing,assetRoot:assets)
            XCTAssertFalse(scene.playSpeech(mood:.normal) {})
            XCTAssertEqual(scene.requestedAction,.idle)
        }
    }
    func testDecodeFailureFallsBackToTextAndSpeechBlocksSameTickAutonomy() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let missing=PetScene(manifest:manifest,assetRoot:assets.appendingPathComponent("missing"))
            var ready=0
            XCTAssertTrue(missing.playSpeech(mood:.normal) { ready+=1 })
            XCTAssertEqual(ready,1);XCTAssertEqual(missing.requestedAction,.idle)
            for step in 0...8 { missing.update(Double(step)*0.25) }
            XCTAssertEqual(ready,1)
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            let state=PetState()
            XCTAssertTrue(PetAutonomy.canStart(state:state,action:scene.requestedAction,visible:true,interacting:false,finishing:false))
            XCTAssertTrue(scene.playSpeech(mood:.normal) {})
            XCTAssertFalse(PetAutonomy.canStart(state:state,action:scene.requestedAction,visible:true,interacting:false,finishing:false))
        }
    }

}
