import XCTest
import PetCore
@testable import PetRendering
final class ActivityRenderingTests: XCTestCase {
    var root: URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testAllGraphsFallbackAndInterruption() throws {
        let manifest=try PetManifest.load(from:root)
        let catalog=try PetCatalog.load(from:root.appendingPathComponent("gameplay.json"))
        for a in catalog.activities {
            for mood in PetMood.allCases {
                let clip=manifest.resolveActivity(graphID:a.graphID,mood:mood)
                XCTAssertEqual(clip.graphID,a.graphID)
                XCTAssertTrue(clip.stages.contains { $0.phase == .loop })
                var timeline=AnimationTimeline(clip:clip,looping:true)
                timeline.advance(3600);XCTAssertFalse(timeline.finished)
            }
        }
        XCTAssertEqual(manifest.resolveActivity(graphID:"unknown",mood:.normal).action,.idle)
        XCTAssertTrue(catalog.items.allSatisfy { $0.imagePath.map { FileManager.default.fileExists(atPath:root.appendingPathComponent($0).path) } ?? false })
    }
    func testSceneItemPathValidationAndActivityRestore() async throws {
        let manifest=try PetManifest.load(from:root), catalog=try PetCatalog.load(from:root.appendingPathComponent("gameplay.json")),assets=root
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.setFoodImage(path:catalog.items[0].imagePath);scene.play(.eat,mood:.normal)
            scene.playActivity(graphID:"study",mood:.normal);XCTAssertEqual(scene.requestedAction,.activity)
            scene.setFoodImage(path:"../escape.png");XCTAssertFalse(scene.hasFoodImage)
            scene.releaseTextures();XCTAssertEqual(scene.cacheBytes,0)
        }
    }
}
