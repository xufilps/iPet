// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import Foundation
import PetCore

public struct HitRegion: Codable, Sendable {
    public let x, y, width, height: Double
    public func contains(x px: Double, y py: Double) -> Bool { px >= x && px <= x + width && py >= y && py <= y + height }
}
public enum AnimationPhase: String, Codable, Sendable { case start, loop, end }
public struct AnimationFrame: Codable, Sendable {
    public let path: String
    public let duration: Double
    public let width, height: Int
    public func canvasSize(width canvasWidth: Double) -> CGSize {
        CGSize(width: canvasWidth, height: canvasWidth * Double(height) / Double(width))
    }
}
public struct AnimationLayer: Codable, Sendable {
    public let z: Int
    public let frames: [AnimationFrame]
    public var duration: Double { frames.reduce(0) { $0 + $1.duration } }
    public func frame(at time: Double) -> AnimationFrame? {
        var cursor = 0.0
        for frame in frames { cursor += frame.duration; if time < cursor { return frame } }
        return frames.last
    }
}
public struct FoodTrackFrame: Codable, Sendable {
    public let duration, x, y, width, rotation, opacity: Double
    public let visible: Bool
}
public struct AnimationStage: Codable, Sendable {
    public let phase: AnimationPhase
    public let layers: [AnimationLayer]
    public let foodTrack: [FoodTrackFrame]
    public var duration: Double { max(layers.map(\.duration).max() ?? 0, foodTrack.reduce(0) { $0 + $1.duration }) }
    public func food(at time: Double) -> FoodTrackFrame? {
        var cursor = 0.0
        for frame in foodTrack { cursor += frame.duration; if time < cursor { return frame } }
        return foodTrack.last
    }
}
public struct AnimationClip: Codable, Sendable {
    public var graphID: String? = nil
    public let action: PetAction
    public let mood: PetMood
    public let stages: [AnimationStage]
}
public struct PetManifest: Codable, Sendable {
    public let version: Int
    public let canvasWidth, canvasHeight: Double
    public let regions: [String: HitRegion]
    public let clips: [AnimationClip]
    public static func load(from root: URL, checkFiles: Bool = true) throws -> PetManifest {
        let manifest = try JSONDecoder().decode(Self.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        try manifest.validate(root: root, checkFiles: checkFiles)
        return manifest
    }
    public func validate(root: URL, checkFiles: Bool) throws {
        func fail(_ message: String) -> NSError { NSError(domain: "VPetAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        guard (1...2).contains(version), canvasWidth.isFinite, canvasHeight.isFinite, canvasWidth > 0, canvasHeight > 0,
              clips.contains(where: { $0.action == .idle && $0.mood == .normal }),
              regions["head"] != nil, regions["body"] != nil else { throw fail("资源清单缺少基础配置。") }
        for region in regions.values {
            guard [region.x, region.y, region.width, region.height].allSatisfy(\.isFinite), region.width > 0, region.height > 0 else { throw fail("互动区域无效。") }
        }
        var identifiers = Set<String>()
        for clip in clips {
            guard identifiers.insert(clip.action.rawValue + (clip.graphID ?? "") + clip.mood.rawValue).inserted, !clip.stages.isEmpty,
                  Set(clip.stages.map(\.phase)).count == clip.stages.count else { throw fail("动画重复或缺少阶段。") }
            for stage in clip.stages {
                guard !stage.layers.isEmpty, Set(stage.layers.map(\.z)).count == stage.layers.count else { throw fail("动画图层无效。") }
                for layer in stage.layers {
                    guard !layer.frames.isEmpty else { throw fail("动画没有帧。") }
                    for frame in layer.frames {
                        guard frame.duration.isFinite, frame.duration > 0, frame.width > 0, frame.height > 0,
                              PetCatalog.safePath(frame.path) else { throw fail("动画帧配置无效。") }
                        if checkFiles && !FileManager.default.fileExists(atPath: root.appendingPathComponent(frame.path).path) { throw fail("缺少动画帧：\(frame.path)") }
                    }
                }
                for frame in stage.foodTrack {
                    guard [frame.duration, frame.x, frame.y, frame.width, frame.rotation, frame.opacity].allSatisfy(\.isFinite), frame.duration > 0, frame.width >= 0, (0...1).contains(frame.opacity) else { throw fail("食物轨迹无效。") }
                }
            }
        }
    }
    public func resolveActivity(graphID: String, mood: PetMood) -> AnimationClip {
        clips.first { $0.action == .activity && $0.graphID == graphID && $0.mood == mood }
        ?? clips.first { $0.action == .activity && $0.graphID == graphID && $0.mood == .normal }
        ?? clips.first { $0.action == .activity && $0.graphID == graphID }
        ?? resolve(action:.idle,mood:mood)
    }
    public func resolve(action: PetAction, mood: PetMood) -> AnimationClip {
        clips.first { $0.action == action && $0.mood == mood }
        ?? clips.first { $0.action == action && $0.mood == .normal }
        ?? clips.first { $0.action == action }
        ?? clips.first { $0.action == .idle && $0.mood == mood }
        ?? clips.first { $0.action == .idle && $0.mood == .normal }!
    }
}
/// Playback state is independent of SpriteKit; an interrupted clip cannot run stale completions.
public struct AnimationTimeline {
    public private(set) var clip: AnimationClip
    public private(set) var stageIndex = 0
    public private(set) var elapsed = 0.0
    public private(set) var finished = false
    private var keepLooping: Bool
    public init(clip: AnimationClip, looping: Bool) { self.clip = clip; keepLooping = looping }
    public var stage: AnimationStage { clip.stages[stageIndex] }
    public mutating func requestFinish() { keepLooping = false }
    public mutating func advance(_ delta: Double) {
        guard !finished, delta.isFinite, delta >= 0 else { return }
        elapsed += delta
        while elapsed >= stage.duration {
            if stage.phase == .loop && keepLooping {
                elapsed.formTruncatingRemainder(dividingBy: stage.duration); return
            }
            elapsed -= stage.duration
            if stageIndex + 1 < clip.stages.count { stageIndex += 1 } else { finished = true; elapsed = stage.duration; return }
        }
    }
}
