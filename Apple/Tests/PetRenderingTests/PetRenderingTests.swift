import XCTest
import PetCore
@testable import PetRendering

final class PetRenderingTests: XCTestCase {
    // Conversion is a deliberate precondition, so missing generated assets fail this suite.
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testConvertedManifestAndFallback() throws {
        let manifest = try PetManifest.load(from: root)
        for action in PetAction.allCases {
            for mood in PetMood.allCases {
                let clip = manifest.resolve(action: action, mood: mood)
                XCTAssertEqual(clip.action, action, "\(action)/\(mood) has no usable action")
                XCTAssertFalse(clip.stages.isEmpty)
            }
        }
        XCTAssertTrue(manifest.regions["head"]!.contains(x: 200, y: 100))
        XCTAssertFalse(manifest.regions["head"]!.contains(x: 0, y: 0))
        XCTAssertEqual(manifest.resolve(action: .head, mood: .poor).mood, .normal)
    }
    func testFrameOrderingDurationAndSandwich() throws {
        let manifest = try PetManifest.load(from: root)
        let frames = manifest.resolve(action: .idle, mood: .normal).stages[0].layers[0].frames
        XCTAssertTrue(frames[0].path.contains("000_"))
        XCTAssertEqual(frames[0].width, 1000)
        XCTAssertEqual(frames[0].canvasSize(width: 500), CGSize(width: 500, height: 500))
        XCTAssertEqual(frames[0].duration, Double(frames[0].path.split(separator: "_").last!.dropLast(4))! / 1000)
        let layer = manifest.resolve(action: .eat, mood: .normal).stages[0]
        XCTAssertEqual(layer.layers.map(\.z), [0, 2]); XCTAssertFalse(layer.foodTrack.isEmpty)
        for action in [PetAction.eat, .drink] {
            for mood in PetMood.allCases {
                let clip = manifest.resolve(action: action, mood: mood)
                for frame in clip.stages[0].layers[0].frames {
                    XCTAssertTrue(frame.path.lowercased().contains("/" + mood.rawValue.lowercased() + "/"), frame.path)
                }
            }
        }
        XCTAssertEqual(frames[0].path, manifest.resolve(action: .idle, mood: .normal).stages[0].layers[0].frame(at: 0)?.path)
    }
    func testStartLoopEndAndInterruption() throws {
        let manifest = try PetManifest.load(from: root)
        let clip = manifest.resolve(action: .raised, mood: .normal)
        var timeline = AnimationTimeline(clip: clip, looping: true)
        XCTAssertEqual(timeline.stage.phase, .start)
        timeline.advance(timeline.stage.duration)
        XCTAssertEqual(timeline.stage.phase, .loop)
        timeline.advance(7200); XCTAssertEqual(timeline.stage.phase, .loop); XCTAssertFalse(timeline.finished)
        timeline.requestFinish(); timeline.advance(timeline.stage.duration)
        XCTAssertEqual(timeline.stage.phase, .end)
        timeline.advance(timeline.stage.duration); XCTAssertTrue(timeline.finished)
        for _ in 0..<10000 {
            timeline = AnimationTimeline(clip: clip, looping: false)
            timeline.advance(0.1); XCTAssertFalse(timeline.finished)
        }
    }
    func testSceneCanvasHitRegionsAndCacheLimit() async throws {
        let assets = root
        let manifest = try PetManifest.load(from: assets)
        await MainActor.run {
            let scene = PetScene(manifest: manifest, assetRoot: assets)
            XCTAssertEqual(scene.region(at: CGPoint(x: 200, y: 400)), "head")
            XCTAssertEqual(scene.region(at: CGPoint(x: 250, y: 250)), "body")
            XCTAssertFalse(scene.isOpaque(at: CGPoint(x: 0, y: 500)))
            XCTAssertTrue(scene.isOpaque(at: CGPoint(x: 250, y: 400)))
            for mood in PetMood.allCases {
                for action in PetAction.allCases { scene.play(action, mood: mood) }
            }
            XCTAssertLessThanOrEqual(scene.cacheBytes, 48 * 1024 * 1024)
            scene.releaseTextures(); XCTAssertEqual(scene.cacheBytes, 0)
        }
    }
    func testMissingFileRejectedAndOneShotFinishes() throws {
        let manifest = try PetManifest.load(from: root)
        XCTAssertThrowsError(try manifest.validate(root: URL(fileURLWithPath: "/missing-vpet-fixture"), checkFiles: true))
        var timeline = AnimationTimeline(clip: manifest.resolve(action: .head, mood: .normal), looping: false)
        timeline.advance(120); XCTAssertTrue(timeline.finished)
    }
}
