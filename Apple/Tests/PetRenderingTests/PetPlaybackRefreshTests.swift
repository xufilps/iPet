import XCTest
import PetCore
@testable import PetRendering
private struct PlaybackRandom:PetRandom { let value:Double;mutating func unit()->Double { value } }
final class PetPlaybackRefreshTests:XCTestCase {
    var root:URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testRebindingPreservesCurrentPhaseAndFinishRequest() throws {
        let manifest=try PetManifest.load(from:root)
        let normal=manifest.resolve(action:.head,mood:.normal),poor=manifest.resolve(action:.head,mood:.poor)
        var timeline=AnimationTimeline(clip:normal,looping:true)
        timeline.advance(timeline.stage.duration)
        timeline.requestFinish()
        XCTAssertTrue(timeline.rebind(clip:poor))
        XCTAssertEqual(timeline.stage.phase,.loop)
        timeline.advance(timeline.stage.duration)
        XCTAssertEqual(timeline.stage.phase,.end)
    }
    func testSelectOnlyCurrentVariantFromOriginalManifest() throws {
        let manifest=try PetManifest.load(from:root)
        let clip=try XCTUnwrap(manifest.resolvePlayback(action:.fidget,graphID:"squat",mood:.normal))
        var low:any PetRandom=PlaybackRandom(value:0),high:any PetRandom=PlaybackRandom(value:1.0.nextDown)
        let a=clip.selectingVariant(phase:.loop,random:&low),b=clip.selectingVariant(phase:.loop,random:&high)
        XCTAssertNotEqual(a.stages.first { $0.phase == .loop }?.layers.first?.frames.first?.path,b.stages.first { $0.phase == .loop }?.layers.first?.frames.first?.path)
        XCTAssertEqual(a.stages.first?.layers.first?.frames.first?.path,b.stages.first?.layers.first?.frames.first?.path)
    }
    func testHeldPinchAndManualSleepRefreshMoodWithoutRestarting() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.onPinchLoop={ true };scene.play(.pinch,mood:.normal);scene.update(0)
            var time=0.0
            while scene.currentPhase != .loop && time<10 { time+=0.1;scene.update(time) }
            scene.setPlaybackMood(.poor)
            for _ in 0..<60 { time+=0.1;scene.update(time) }
            XCTAssertEqual(scene.requestedAction,.pinch);XCTAssertEqual(scene.currentPhase,.loop);XCTAssertEqual(scene.mood,.poor)
            scene.play(.sleep,mood:.normal)
            scene.update(time)
            for _ in 0..<100 { time+=0.1;scene.update(time) }
            scene.setPlaybackMood(.happy)
            for _ in 0..<100 { time+=0.1;scene.update(time) }
            XCTAssertEqual(scene.requestedAction,.sleep);XCTAssertEqual(scene.currentPhase,.loop);XCTAssertEqual(scene.mood,.happy)
            scene.finishAction()
            for _ in 0..<100 { time+=0.1;scene.update(time) }
            XCTAssertEqual(scene.requestedAction,.idle)
        }
    }
    func testMissingIllPinchEndsAndSettlesToCurrentMood() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            var finished=0
            scene.onActionFinished={ if $0 == .pinch { finished+=1 } }
            scene.onPinchLoop={ true }
            scene.play(.pinch,mood:.normal);scene.update(0)
            var time=0.0
            while scene.currentPhase != .loop && time<10 { time+=0.1;scene.update(time) }
            scene.setPlaybackMood(.ill)
            for _ in 0..<200 { time+=0.1;scene.update(time) }
            XCTAssertEqual(finished,1);XCTAssertEqual(scene.requestedAction,.idle);XCTAssertEqual(scene.mood,.ill)
        }
    }

    func testNewSpecialIdleUsesExplicitMoodInsteadOfPreviousQueue() async throws {
        let assets=root,manifest=try PetManifest.load(from:root)
        await MainActor.run {
            let scene=PetScene(manifest:manifest,assetRoot:assets)
            scene.play(.pinch,mood:.normal)
            scene.setPlaybackMood(.ill)
            XCTAssertTrue(scene.playSpecialIdle(mood:.happy))
            XCTAssertEqual(scene.requestedAction,.specialIdle)
            XCTAssertEqual(scene.mood,.happy)
        }
    }
}
