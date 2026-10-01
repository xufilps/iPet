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
    func testActivityEndRestoresLatestGraphOnlyOnce() async throws {
        let manifest=try PetManifest.load(from:root), assets=root
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.playActivity(graphID:"workone",mood:.normal)
            var finished=0;var latest="study"
            scene.onActionFinished = { _ in finished += 1;scene.playActivity(graphID:latest,mood:.normal) }
            XCTAssertTrue(scene.finishActivity())
            XCTAssertTrue(scene.isFinishingActivity)
            XCTAssertEqual(scene.requestedGraphID,"workone")
            var next=PetState();next.activity=ActivitySession(activityID:"next")
            let catalog=PetCatalog(activities:[ActivityDefinition(id:"next",name:"学习",graphID:"study",kind:.study,durationSeconds:3600,moneyBase:8,strengthFood:1,strengthDrink:1,feeling:1,finishBonus:0.1)])
            XCTAssertFalse(scene.restoreBase(state:next,catalog:catalog))
            XCTAssertEqual(scene.requestedGraphID,"workone")
            latest="playone" // A second start during the ending restores the newest session.
            for i in 0...400 { scene.update(Double(i)*0.25) }
            XCTAssertEqual(finished,1);XCTAssertEqual(scene.requestedGraphID,"playone")
            XCTAssertFalse(scene.isFinishingActivity)
            scene.play(.head,mood:.normal);XCTAssertFalse(scene.finishActivity())
        }
    }
}
