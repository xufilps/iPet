// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import Foundation
@preconcurrency import SpriteKit
import ImageIO
import PetCore

@MainActor final class TextureCache {
    struct Entry { let texture: SKTexture; let alpha: [UInt8]; let bytes: Int; var used: UInt64 }
    private var entries: [String: Entry] = [:]
    private var generation: UInt64 = 0
    private(set) var bytes = 0
    let limit = 48 * 1024 * 1024
    var pixelWidth = 640
    func get(_ frame: AnimationFrame, root: URL) -> Entry? {
        generation &+= 1
        if var entry = entries[frame.path] { entry.used = generation; entries[frame.path] = entry; return entry }
        guard let source = CGImageSourceCreateWithURL(root.appendingPathComponent(frame.path) as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: pixelWidth,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        var pixels = [UInt8](repeating: 0, count: 100 * 100 * 4)
        let valid = pixels.withUnsafeMutableBytes { pointer -> Bool in
            guard let context = CGContext(data: pointer.baseAddress, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 100, height: 100)); return true
        }
        guard valid else { return nil }
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        let cost = image.width * image.height * 4 + alpha.count
        while bytes + cost > limit, let oldest = entries.min(by: { $0.value.used < $1.value.used }) {
            bytes -= oldest.value.bytes; entries.removeValue(forKey: oldest.key)
        }
        let entry = Entry(texture: SKTexture(cgImage: image), alpha: alpha, bytes: cost, used: generation)
        if cost <= limit { entries[frame.path] = entry; bytes += cost }
        return entry
    }
    func clear() { entries.removeAll(); bytes = 0 }
}

@MainActor public final class PetScene: SKScene {
    public let manifest: PetManifest
    public let assetRoot: URL
    public private(set) var requestedAction = PetAction.idle
    public private(set) var mood = PetMood.normal
    public var onActionFinished: ((PetAction) -> Void)?
    public var onDiagnostic: ((String) -> Void)?
    private var timeline: AnimationTimeline?
    private let cache = TextureCache()
    private var sprites: [Int: SKSpriteNode] = [:]
    private var masks: [Int: [UInt8]] = [:]
    private var framePaths: [Int: String] = [:]
    private let item = SKLabelNode(fontNamed: "Apple Color Emoji")
    private var previousTime: TimeInterval?
    public var cacheBytes: Int { cache.bytes }
    public init(manifest: PetManifest, assetRoot: URL) {
        self.manifest = manifest; self.assetRoot = assetRoot
        super.init(size: CGSize(width: manifest.canvasWidth, height: manifest.canvasHeight))
        scaleMode = .aspectFit; backgroundColor = .clear
        item.zPosition = 1; item.verticalAlignmentMode = .center; item.horizontalAlignmentMode = .center
        addChild(item)
        play(.idle, mood: .normal)
    }
    required init?(coder: NSCoder) { fatalError("Use manifest initializer") }
    public func play(_ action: PetAction, mood: PetMood) {
        requestedAction = action; self.mood = mood
        let clip = manifest.resolve(action: action, mood: mood)
        if clip.action != action || clip.mood != mood { onDiagnostic?("动画回退：\(action.rawValue)/\(mood.rawValue) → \(clip.action.rawValue)/\(clip.mood.rawValue)") }
        timeline = AnimationTimeline(clip: clip, looping: [.idle, .sleep, .raised, .walkLeft, .walkRight].contains(action))
        previousTime = nil
        for node in sprites.values { node.removeFromParent() }
        sprites.removeAll(); masks.removeAll(); framePaths.removeAll(); item.isHidden = true
        render()
    }
    public func setTextureResolution(pixelWidth: Int) {
        let target = min(1024, max(256, ((pixelWidth + 127) / 128) * 128))
        guard cache.pixelWidth != target else { return }
        releaseTextures(); cache.pixelWidth = target; render()
    }
    public func finishAction() { timeline?.requestFinish() }
    public func resetTiming() { previousTime = nil }
    public func releaseTextures() {
        for node in sprites.values { node.texture = nil }
        framePaths.removeAll(); masks.removeAll(); cache.clear()
    }
    nonisolated public override func update(_ currentTime: TimeInterval) {
        MainActor.assumeIsolated { advance(currentTime) }
    }
    private func advance(_ currentTime: TimeInterval) {
        defer { previousTime = currentTime }
        if let previousTime { timeline?.advance(min(max(currentTime - previousTime, 0), 0.25)) }
        if timeline?.finished == true {
            let completed = requestedAction
            play(.idle, mood: mood); onActionFinished?(completed)
        }
        render()
    }
    private func render() {
        guard let timeline else { return }
        let stage = timeline.stage, elapsed = timeline.elapsed
        let active = Set(stage.layers.map(\.z))
        for z in Array(sprites.keys) where !active.contains(z) { sprites.removeValue(forKey: z)?.removeFromParent(); masks.removeValue(forKey: z); framePaths.removeValue(forKey: z) }
        for layer in stage.layers {
            guard let frame = layer.frame(at: elapsed) else { continue }
            let sprite: SKSpriteNode
            if let existing = sprites[layer.z] { sprite = existing } else {
                sprite = SKSpriteNode(); sprite.anchorPoint = CGPoint(x: 0, y: 1)
                sprite.position = CGPoint(x: 0, y: size.height); sprite.zPosition = CGFloat(layer.z)
                sprites[layer.z] = sprite; addChild(sprite)
            }
            if framePaths[layer.z] != frame.path {
                if let entry = cache.get(frame, root: assetRoot) {
                    sprite.texture = entry.texture; sprite.size = frame.canvasSize(width: size.width)
                    masks[layer.z] = entry.alpha; framePaths[layer.z] = frame.path
                } else {
                    sprite.texture = nil; masks.removeValue(forKey: layer.z)
                    onDiagnostic?("无法解码动画帧：\(frame.path)")
                    if requestedAction != .idle { play(.idle, mood: mood); return }
                }
            }
        }
        if let food = stage.food(at: elapsed), food.visible {
            item.text = requestedAction == .drink ? "🥛" : "🍞"
            item.fontSize = food.width; item.alpha = food.opacity
            item.position = CGPoint(x: food.x + food.width / 2, y: size.height - food.y - food.width / 2)
            item.zRotation = -food.rotation * .pi / 180; item.isHidden = false
        } else { item.isHidden = true }
    }
    /// Scene coordinates (bottom-left) mapped to the original image's top-left canvas.
    public func region(at point: CGPoint) -> String? {
        let x = Double(point.x), y = Double(size.height - point.y)
        if manifest.regions["head"]?.contains(x: x, y: y) == true { return "head" }
        if manifest.regions["body"]?.contains(x: x, y: y) == true { return "body" }
        return nil
    }
    public func isOpaque(at point: CGPoint) -> Bool {
        if !item.isHidden && item.contains(point) { return true }
        for (z, sprite) in sprites {
            guard let alpha = masks[z], sprite.size.width > 0, sprite.size.height > 0 else { continue }
            let x = Int((point.x - sprite.position.x) / sprite.size.width * 100)
            let y = Int((sprite.position.y - point.y) / sprite.size.height * 100)
            if (0..<100).contains(x), (0..<100).contains(y), alpha[y * 100 + x] > 24 { return true }
        }
        return false
    }
}
