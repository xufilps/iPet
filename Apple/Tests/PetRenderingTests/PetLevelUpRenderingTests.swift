// SPDX-License-Identifier: Apache-2.0
import XCTest
import PetCore
@testable import PetRendering
final class PetLevelUpRenderingTests:XCTestCase {
    var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testThreeOriginalStatesFinishExactlyOnce() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            for mood in [PetMood.happy,.normal,.poor] {
                let scene=PetScene(manifest:manifest,assetRoot:assets)
                var completed=0
                scene.onActionFinished={ if $0 == .levelUp { completed+=1 } }
                XCTAssertTrue(scene.playLevelUp(mood:mood));XCTAssertEqual(scene.requestedAction,.levelUp)
                for step in 0...24 { scene.update(Double(step)*0.25) }
                XCTAssertEqual(completed,1);XCTAssertEqual(scene.requestedAction,.idle)
            }
        }
    }
    func testIllBusyAndInterruptedRequestsDoNotUseFallbackOrFinishTwice() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            XCTAssertFalse(scene.playLevelUp(mood:.ill));XCTAssertEqual(scene.requestedAction,.idle)
            scene.playActivity(graphID:"workone",mood:.normal)
            XCTAssertFalse(scene.playLevelUp(mood:.normal));XCTAssertEqual(scene.requestedAction,.activity)
            scene.play(.idle,mood:.normal)
            var completed=0
            scene.onActionFinished={ if $0 == .levelUp { completed+=1 } }
            XCTAssertTrue(scene.playLevelUp(mood:.normal));scene.play(.head,mood:.normal)
            for step in 0...24 { scene.update(Double(step)*0.25) }
            XCTAssertEqual(completed,0);XCTAssertEqual(scene.requestedAction,.idle)
        }
    }
    func testOriginalDurationBoundaryAndIllDiagnostic() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        let clip=try XCTUnwrap(manifest.clips.first { $0.action == .levelUp && $0.mood == .normal })
        let duration=clip.stages.reduce(0) { $0+$1.duration }
        XCTAssertEqual(duration,3.625,accuracy:1e-10)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            var completed=0,diagnostics=[String]()
            scene.onActionFinished={ if $0 == .levelUp { completed+=1 } }
            scene.onDiagnostic={ diagnostics.append($0) }
            XCTAssertFalse(scene.playLevelUp(mood:.ill))
            XCTAssertTrue(diagnostics.contains { $0.contains("无升级动画") && $0.contains("Ill") })
            XCTAssertTrue(scene.playLevelUp(mood:.normal))
            for step in 0..<Int(duration/0.125) { scene.update(Double(step)*0.125) }
            scene.update(duration-0.001);XCTAssertEqual(completed,0)
            XCTAssertEqual(scene.requestedAction,.levelUp)
            scene.update(duration+0.001);XCTAssertEqual(completed,1)
            XCTAssertEqual(scene.requestedAction,.idle)
        }
    }

}
