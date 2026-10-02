import XCTest
@preconcurrency import SpriteKit
import PetCore
@testable import PetRendering
private struct VariantRandom: PetRandom { var value: Double; mutating func unit() -> Double { value } }
final class ActivityRenderingTests: XCTestCase {
    func testMovementGraphPreservesStartAndInterruptClearsGraph() async throws {
        let manifest=try PetManifest.load(from:root),assets=root
        let clip=try XCTUnwrap(manifest.clips.first { $0.graphID=="crawl.right" && $0.mood == .normal })
        let start=try XCTUnwrap(clip.stages.first { $0.phase == .start })
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.playMovement(.walkRight,graphID:"crawl.right",mood:.normal)
            XCTAssertEqual(scene.requestedGraphID,"crawl.right");XCTAssertEqual(scene.currentPhase,.start)
            scene.update(0)
            for step in 1...Int(ceil(start.duration/0.1)+1) { scene.update(Double(step)*0.1) }
            XCTAssertEqual(scene.currentPhase,.loop)
            scene.play(.head,mood:.normal)
            XCTAssertNil(scene.requestedGraphID);XCTAssertEqual(scene.currentPhase,.start)
        }
    }
    func testMovementBoundaryEndsWithoutExtraLoopAndReplacementKeepsStart() async throws {
        let manifest=try PetManifest.load(from:root),assets=root
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.playMovement(.walkRight,graphID:"crawl.right",mood:.normal)
            var calls=0
            scene.onMovementLoop={ calls+=1;return false }
            scene.update(0)
            var time=0.0
            while calls==0 && time<10 { time+=0.25;scene.update(time) }
            XCTAssertEqual(calls,1);XCTAssertEqual(scene.currentPhase,.end)
            calls=0
            scene.playMovement(.walkRight,graphID:"crawl.right",mood:.normal)
            scene.onMovementLoop={ calls+=1;scene.playMovement(.walkLeft,graphID:"walk.left.faster",mood:.happy);return true }
            scene.update(time)
            let limit=time+10
            while calls==0 && time<limit { time+=0.25;scene.update(time) }
            XCTAssertEqual(calls,1);XCTAssertEqual(scene.requestedGraphID,"walk.left.faster")
            XCTAssertEqual(scene.currentPhase,.start)
            scene.onMovementLoop=nil
        }
    }
    func testMissingAllMovementClipsReturnsToIdleSelection() async throws {
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("manifest.json"))) as? [String:Any])
        let clips=try XCTUnwrap(object["clips"] as? [[String:Any]])
        object["clips"]=clips.filter { !["walkLeft","walkRight"].contains($0["action"] as? String ?? "") }
        let manifest=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:object)),assets=root
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.playMovement(.walkRight,graphID:"crawl.right",mood:.normal)
            XCTAssertEqual(scene.requestedAction,.idle)
            XCTAssertFalse(scene.isMovementAnimation)
        }
    }
    func testClimbingUsesItsGraphAndMovementLoopCallback() async throws {
        let manifest=try PetManifest.load(from:root),assets=root
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            var calls=0
            scene.onMovementLoop={ calls+=1;return false }
            scene.playMovement(.climb,graphID:"climb.left",mood:.normal)
            XCTAssertEqual(scene.requestedGraphID,"climb.left");XCTAssertTrue(scene.isMovementAnimation)
            scene.update(0)
            var time=0.0
            while calls==0 && time<10 { time+=0.25;scene.update(time) }
            XCTAssertEqual(calls,1);XCTAssertEqual(scene.currentPhase,.end)
            scene.onMovementLoop=nil
        }
    }
    func testUndecodableClimbNotifiesOwnerForPositionRecovery() async throws {
        let manifest=try PetManifest.load(from:root)
        let missing=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:missing)
            var completed:[PetAction]=[]
            scene.onActionFinished={ completed.append($0) }
            scene.playMovement(.climb,graphID:"climb.left",mood:.normal)
            XCTAssertEqual(scene.requestedAction,.idle)
            XCTAssertEqual(completed,[.climb])
            scene.onActionFinished=nil
        }
    }
    func testMissingRightClimbDoesNotUseLeftWallAnimation() async throws {
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("manifest.json"))) as? [String:Any])
        let clips=try XCTUnwrap(object["clips"] as? [[String:Any]])
        object["clips"]=clips.filter { $0["graphID"] as? String != "climb.right" }
        let manifest=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:object)),assets=root
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.playMovement(.climb,graphID:"climb.right",mood:.normal)
            XCTAssertEqual(scene.requestedAction,.idle)
        }
    }
    var root: URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testRepeatTouchPreservesStartAndContinuesOnlyOneLoop() throws {
        let manifest=try PetManifest.load(from:root)
        var timeline=AnimationTimeline(clip:manifest.resolve(action:.head,mood:.normal),looping:false)
        XCTAssertFalse(timeline.requestContinue())
        timeline.advance(timeline.stage.duration)
        XCTAssertEqual(timeline.stage.phase,.loop)
        XCTAssertTrue(timeline.requestContinue());XCTAssertTrue(timeline.requestContinue())
        timeline.advance(timeline.stage.duration)
        XCTAssertEqual(timeline.stage.phase,.loop)
        timeline.advance(timeline.stage.duration)
        XCTAssertEqual(timeline.stage.phase,.end)
        XCTAssertFalse(timeline.requestContinue())
    }
    func testSceneRepeatedTouchKeepsStartVariantAndRaisedAreaMatchesMood() async throws {
        let manifest=try PetManifest.load(from:root),assets=root
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            XCTAssertTrue(scene.canRaise(at:CGPoint(x:200,y:400),mood:.normal))
            XCTAssertFalse(scene.canRaise(at:CGPoint(x:200,y:400),mood:.ill))
            XCTAssertTrue(scene.canRaise(at:CGPoint(x:200,y:200),mood:.ill))
            scene.playTouch(.head,mood:.normal)
            let first=scene.children.filter { $0.zPosition == 0 }.first
            scene.update(0);scene.update(0.1)
            scene.playTouch(.head,mood:.normal)
            XCTAssertTrue(first === scene.children.filter { $0.zPosition == 0 }.first)
            scene.playTouch(.body,mood:.normal)
            XCTAssertEqual(scene.requestedAction,.body)
        }
    }
    func testUndecodableTransitionFallsBackToTargetMood() async throws {
        let manifest=try PetManifest.load(from:root)
        let missing=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:missing)
            var finished=0;scene.onActionFinished = { _ in finished += 1 }
            XCTAssertTrue(scene.playMoodTransition(from:.normal,to:.ill))
            XCTAssertEqual(scene.requestedAction,.idle)
            XCTAssertEqual(scene.mood,.ill)
            XCTAssertEqual(finished,1)
        }
    }
    func testVariantValidationRejectsBadFramesAndLoadsLegacyManifest() throws {
        let data=try Data(contentsOf:root.appendingPathComponent("manifest.json"))
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        var clips=try XCTUnwrap(json["clips"] as? [[String:Any]])
        let index=try XCTUnwrap(clips.firstIndex { $0["action"] as? String == "idle" })
        var stages=try XCTUnwrap(clips[index]["stages"] as? [[String:Any]])
        stages[0]["variants"]=[[ ["z":0,"frames":[["path":"../escape.png","duration":0.1,"width":1,"height":1]]] ]]
        clips[index]["stages"]=stages;json["clips"]=clips
        let invalid=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertThrowsError(try invalid.validate(root:root,checkFiles:false))
        json["version"]=2
        for i in clips.indices {
            var legacy=clips[i]["stages"] as! [[String:Any]]
            for j in legacy.indices { legacy[j].removeValue(forKey:"variants") }
            clips[i]["stages"]=legacy
        }
        json["clips"]=clips
        let valid=try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:json))
        try valid.validate(root:root,checkFiles:true)
    }
    func testVariantsChooseOnceAndKeepValidFrames() throws {
        let manifest=try PetManifest.load(from:root)
        let clip=manifest.resolve(action:.idle,mood:.normal)
        var first:any PetRandom=VariantRandom(value:0),last:any PetRandom=VariantRandom(value:0.999)
        let a=clip.selectingVariants(random:&first), b=clip.selectingVariants(random:&last)
        XCTAssertNotEqual(a.stages[0].layers[0].frames[0].path,b.stages[0].layers[0].frames[0].path)
        var timeline=AnimationTimeline(clip:b,looping:true)
        timeline.advance(100)
        XCTAssertEqual(timeline.clip.stages[0].layers[0].frames[0].path,b.stages[0].layers[0].frames[0].path)
    }
    func testMoodTransitionsSettleRetargetAndCancelOnInteraction() async throws {
        let manifest=try PetManifest.load(from:root),assets=root
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            var completions=0;scene.onActionFinished = { _ in completions += 1 }
            scene.play(.idle,mood:.happy)
            XCTAssertTrue(scene.playMoodTransition(from:.happy,to:.ill))
            XCTAssertEqual(scene.requestedAction,.stateDown);XCTAssertEqual(scene.mood,.happy)
            var visited=Set<PetMood>()
            for i in 0...600 { visited.insert(scene.mood);scene.update(Double(i)*0.25) }
            XCTAssertTrue(visited.isSuperset(of:[.happy,.normal,.poor,.ill]))
            XCTAssertEqual(scene.mood,.ill);XCTAssertEqual(scene.requestedAction,.idle);XCTAssertEqual(completions,1)
            scene.play(.idle,mood:.normal)
            XCTAssertTrue(scene.playMoodTransition(from:.normal,to:.ill))
            XCTAssertTrue(scene.playMoodTransition(from:.poor,to:.happy))
            for i in 0...600 { scene.update(Double(i)*0.25) }
            XCTAssertEqual(scene.mood,.happy);XCTAssertEqual(completions,2)
            XCTAssertTrue(scene.playMoodTransition(from:.happy,to:.ill))
            scene.play(.head,mood:.normal)
            for i in 0...600 { scene.update(Double(i)*0.25) }
            XCTAssertEqual(scene.mood,.normal);XCTAssertEqual(completions,3)
            scene.play(.eat,mood:.normal)
            XCTAssertFalse(scene.playMoodTransition(from:.normal,to:.ill))
            XCTAssertEqual(scene.requestedAction,.eat)
        }
    }
    func testAutonomousClipsFinishAndRestoreWithoutChangingRestState() async throws {
        let manifest=try PetManifest.load(from:root), assets=root
        for graph in ["boring","squat"] {
            XCTAssertTrue(manifest.clips.contains { $0.action == .fidget && $0.graphID == graph })
        }
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            var cycles=0;scene.onIdleCycle = { cycles += 1 }
            for i in 0...100 { scene.update(Double(i)*0.25) }
            XCTAssertGreaterThan(cycles,0)
            var finished=0;scene.onActionFinished = { _ in finished += 1 }
            scene.playFidget(graphID:"squat",mood:.normal)
            for i in 0...400 { scene.update(Double(i)*0.25) }
            XCTAssertEqual(finished,1);XCTAssertEqual(scene.requestedAction,.idle)
            scene.play(.sleep,mood:.normal);scene.finishAction()
            for i in 0...400 { scene.update(Double(i)*0.25) }
            XCTAssertEqual(finished,2)
            scene.playFidget(graphID:"boring",mood:.normal)
            scene.play(.head,mood:.normal)
            for i in 0...400 { scene.update(Double(i)*0.25) }
            XCTAssertEqual(finished,3) // Interrupted fidget never fires its old callback.
        }
    }
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
    func testMissingFoodImageNeverShowsSolidSprite() async throws {
        let manifest=try PetManifest.load(from:root), assets=root
        await MainActor.run {
            for action in [PetAction.eat,.drink,.gift] {
                let scene=PetScene(manifest:manifest,assetRoot:assets)
                var diagnostics:[String]=[];scene.onDiagnostic={ diagnostics.append($0) }
                scene.setFoodImage(path:"items/missing.png");scene.play(action,mood:.normal)
                let item=scene.children.first { $0.zPosition == 1 }!
                for i in 0...60 { scene.update(Double(i)*0.25);XCTAssertTrue(item.isHidden,"missing image must not become a colored rectangle") }
                XCTAssertFalse(diagnostics.isEmpty)
            }
        }
    }
    func testFoodTextureIsVisibleAndReloadsAfterRelease() async throws {
        let manifest=try PetManifest.load(from:root),catalog=try PetCatalog.load(from:root.appendingPathComponent("gameplay.json")),assets=root
        let path=try XCTUnwrap(catalog.items.first { $0.graphID.lowercased()=="drink" }?.imagePath)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets);scene.setFoodImage(path:path);scene.play(.drink,mood:.normal)
            let item=scene.children.first { $0.zPosition == 1 } as! SKSpriteNode
            scene.releaseTextures();XCTAssertNil(item.texture)
            var visible=false
            for i in 0...40 { scene.update(Double(i)*0.25);if !item.isHidden { visible=true;XCTAssertNotNil(item.texture) } }
            XCTAssertTrue(visible)
        }
    }
}
