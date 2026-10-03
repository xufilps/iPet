// SPDX-License-Identifier: Apache-2.0
import XCTest
import PetCore
@testable import PetRendering
final class PetMovementFailureTests:XCTestCase {
    private var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testDecodeFailureReportsFailureBeforeFinishWithoutSuccessfulMovement() async throws {
        let manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:URL(fileURLWithPath:"/missing-ipet-animation-fixture"))
            var events:[String]=[]
            scene.onMovementFailed={ events.append("failure") }
            scene.onActionFinished={ _ in events.append("finish") }
            scene.onMovementCompleted={ events.append("success");return false }
            scene.playMovement(.climb,graphID:"climb.left",mood:.normal)
            XCTAssertEqual(events,["failure","finish"]);XCTAssertEqual(scene.requestedAction,.idle)
        }
    }
    func testEndFrameDecodeFailureReportsFailureEvenAfterStop() async throws {
        let assets=root,manifest=try PetManifest.load(from:assets)
        var raw=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(manifest)) as? [String:Any])
        var clips=try XCTUnwrap(raw["clips"] as? [[String:Any]])
        let index=try XCTUnwrap(clips.firstIndex { $0["graphID"] as? String == "walk.left" && $0["mood"] as? String == PetMood.normal.rawValue })
        func breakEndFrames(_ value:Any,inEnd:Bool=false) -> Any {
            if var map=value as? [String:Any] {
                let end=inEnd || map["phase"] as? String == "end"
                for (key,value) in map { map[key]=key == "path" && end ? "missing-ipet-end-frame.png":breakEndFrames(value,inEnd:end) }
                return map
            }
            if let array=value as? [Any] { return array.map { breakEndFrames($0,inEnd:inEnd) } }
            return value
        }
        clips[index]=try XCTUnwrap(breakEndFrames(clips[index]) as? [String:Any]);raw["clips"]=clips
        let broken=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:raw))
        await MainActor.run {
            let scene=PetScene(manifest:broken,assetRoot:assets)
            var failures=0,successes=0,stops=0
            scene.onMovementFailed={ failures+=1 }
            scene.onMovementCompleted={ successes+=1;return false }
            scene.onMovementLoop={ stops+=1;return false }
            scene.playMovement(.walkLeft,graphID:"walk.left",mood:.normal)
            for index in 0..<200 { scene.update(Double(index)*0.1) }
            XCTAssertEqual(stops,1);XCTAssertEqual(failures,1);XCTAssertEqual(successes,0)
            XCTAssertEqual(scene.requestedAction,.idle)
        }
    }
}
