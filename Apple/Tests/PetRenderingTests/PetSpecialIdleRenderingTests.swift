import XCTest
import PetCore
@testable import PetRendering
private struct SpecialSequence:PetRandom { var values:[Double];mutating func unit()->Double { values.isEmpty ? 1.0.nextDown:values.removeFirst() } }
final class PetSpecialIdleRenderingTests:XCTestCase {
    var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testOneTwoEndReturnsToOneLoopBeforeFinishing() async throws {
        let assets=root
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("manifest.json"))) as? [String:Any])
        var clips=try XCTUnwrap(object["clips"] as? [[String:Any]])
        for i in clips.indices {
            var stages=clips[i]["stages"] as! [[String:Any]]
            for j in stages.indices { stages[j].removeValue(forKey:"variants") }
            clips[i]["stages"]=stages
        }
        object["clips"]=clips
        let manifest=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:object))
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets,random:SpecialSequence(values:Array(repeating:1.0.nextDown,count:11)+[0]))
            var finished=0,seenTwo=false,returned=false
            scene.onActionFinished={ if $0 == .specialIdle { finished+=1 } }
            XCTAssertTrue(scene.playSpecialIdle(mood:.normal));scene.update(0)
            for step in 1...2000 {
                scene.update(Double(step)*0.25)
                if scene.requestedGraphID == "state.two" { seenTwo=true }
                if seenTwo && scene.requestedGraphID == "state.one" && scene.currentPhase == .loop { returned=true;XCTAssertEqual(finished,0) }
            }
            XCTAssertTrue(seenTwo);XCTAssertTrue(returned);XCTAssertEqual(finished,1)
            XCTAssertFalse(scene.playSpecialIdle(mood:.ill))
            XCTAssertTrue(scene.playSpecialIdle(mood:.normal));scene.finishAction()
            for step in 1...100 { scene.update(500+Double(step)*0.25) }
            XCTAssertNotEqual(scene.requestedAction,.specialIdle)
        }
    }
    func testDozeProbabilityEndsButManualSleepStays() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets,random:SpecialSequence(values:[]))
            scene.playDoze(mood:.normal);scene.update(0)
            for step in 1...2000 { scene.update(Double(step)*0.25) }
            XCTAssertEqual(scene.requestedAction,.idle)
            scene.play(.sleep,mood:.normal);scene.update(501)
            for step in 1...2000 { scene.update(501+Double(step)*0.25) }
            XCTAssertEqual(scene.requestedAction,.sleep)
        }
    }
}
