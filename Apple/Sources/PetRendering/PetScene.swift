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
    public var onIdleCycle: (() -> Void)?
    public var onPinchLoop:(()->Bool)?
    public var onMovementLoop:(()->Bool)?
    private var timelineGeneration=0
    public var onActionFinished: ((PetAction) -> Void)?
    public var onDiagnostic: ((String) -> Void)?
    private var timeline: AnimationTimeline?
    private var sideHideMain:AnimationClip?
    private var sideHideReturning=false
    private(set) var raisedCycles:Int?
    private var fidgetCycles:PetIdleCycles?
    private var specialIdle:PetSpecialIdle?
    private var specialReturning=false
    private var playbackMood:PetMood?
    private var random: any PetRandom
    private var transitionSteps: [PetMoodTransition] = []
    private var transitionTarget: PetMood?
    private let cache = TextureCache()
    private var sprites: [Int: SKSpriteNode] = [:]
    private var masks: [Int: [UInt8]] = [:]
    private var framePaths: [Int: String] = [:]
    private let item = SKSpriteNode(color: .white, size: .zero)
    private var foodPath: String?
    private var reportedMissingFood = false
    public var hasFoodImage: Bool { foodPath != nil && item.texture != nil }
    public private(set) var requestedGraphID: String?
    public private(set) var isFinishingActivity = false
    private var previousTime: TimeInterval?
    public var cacheBytes: Int { cache.bytes }
    public init(manifest: PetManifest, assetRoot: URL, random: any PetRandom = SeededPetRandom(seed: UInt64.random(in: 0...UInt64.max))) {
        self.manifest = manifest; self.assetRoot = assetRoot; self.random = random
        super.init(size: CGSize(width: manifest.canvasWidth, height: manifest.canvasHeight))
        scaleMode = .aspectFit; backgroundColor = .clear
        item.zPosition = 1
        addChild(item)
        play(.idle, mood: .normal)
    }
    required init?(coder: NSCoder) { fatalError("Use manifest initializer") }
    public func canPinch(at point:CGPoint,mood:PetMood) -> Bool {
        manifest.regions["pinch"]?.contains(x:Double(point.x),y:Double(size.height-point.y)) == true
            && manifest.clips.contains { $0.action == .pinch && $0.mood == mood && $0.stages.contains { $0.phase == .start } }
    }
    public func canRaise(at point: CGPoint, mood: PetMood) -> Bool {
        manifest.regions["raised:"+mood.rawValue]?.contains(x:Double(point.x),y:Double(size.height-point.y)) == true
    }
    public func beginRaise(mood:PetMood) {
        play(.raised,mood:mood)
        guard let clip=manifest.clips.first(where: { $0.action == .raised && $0.graphID == "raised.dynamic" && $0.mood == mood })
            ?? manifest.clips.first(where: { $0.action == .raised && $0.graphID == "raised.dynamic" && $0.mood == .normal }) else {
            onDiagnostic?("动态提起动画缺失，回静态提起。");return
        }
        raisedCycles=0;requestedGraphID="raised.dynamic"
        if clip.mood != mood { onDiagnostic?("动态提起状态回退：\(mood.rawValue)") }
        timeline=AnimationTimeline(clip:clip.selectingVariants(random:&random),looping:false);installTimeline()
    }
    public func updateRaiseMotion(distance:Double) {
        guard requestedAction == .raised,distance.isFinite,distance>20 else { return }
        if let cycle=raisedCycles { if cycle>=1 { raisedCycles=0 } }
        else if currentPhase != .end { beginRaise(mood:mood) }
    }
    public func finishRaise() {
        guard requestedAction == .raised else { return }
        raisedCycles=nil
        let target=playbackMood ?? mood
        let clip=manifest.resolvePlayback(action:.raised,graphID:"raised.static",mood:target) ?? manifest.resolve(action:.raised,mood:target)
        mood=target
        let end=clip.stages.filter { $0.phase == .end }
        guard !end.isEmpty else { play(.idle,mood:mood);onActionFinished?(.raised);return }
        requestedGraphID="raised.static"
        timeline=AnimationTimeline(clip:AnimationClip(graphID:clip.graphID,action:clip.action,mood:clip.mood,stages:end),looping:false);installTimeline()
    }
    public func playTouch(_ action: PetAction, mood: PetMood) {
        if [.head,.body].contains(action), requestedAction == action, let current=timeline, current.clip.action == action {
            if current.stage.phase == .start { return }
            if timeline?.requestContinue() == true { return }
        }
        play(action,mood:mood)
    }
    public func play(_ action: PetAction, mood: PetMood) {
        sideHideMain=nil;sideHideReturning=false;raisedCycles=nil;fidgetCycles=nil;specialIdle=nil;specialReturning=false;playbackMood=nil
        transitionSteps=[];transitionTarget=nil
        isFinishingActivity=false; requestedGraphID=nil
        requestedAction = action; self.mood = mood
        let clip = manifest.resolve(action: action, mood: mood)
        if clip.action != action || clip.mood != mood { onDiagnostic?("动画回退：\(action.rawValue)/\(mood.rawValue) → \(clip.action.rawValue)/\(clip.mood.rawValue)") }
        timeline = AnimationTimeline(clip: clip.selectingVariants(random:&random), looping: [.idle, .sleep, .raised, .walkLeft, .walkRight, .climb, .pinch].contains(action))
        installTimeline()
    }
    public func setPlaybackMood(_ mood:PetMood) { playbackMood=mood }
    private func refreshPlayback(phase:AnimationPhase) {
        guard ![.stateUp,.stateDown].contains(requestedAction) else { return }
        let target=playbackMood ?? mood
        guard let raw=manifest.resolvePlayback(action:requestedAction,graphID:requestedGraphID,mood:target),raw.stages.contains(where: { $0.phase == phase }) else {
            onDiagnostic?("阶段资源缺失，结束当前动作：\(requestedAction.rawValue)/\(target.rawValue)/\(phase.rawValue)")
            if requestedAction == .sideHide { sideHideMain=nil }
            finishAction();return
        }
        if timeline?.rebind(clip:raw.selectingVariant(phase:phase,random:&random)) == true { mood=target }
        if sideHideMain != nil,let graph=sideHideMain?.graphID { sideHideMain=manifest.resolvePlayback(action:.sideHide,graphID:graph,mood:target) }
    }
    private func installTimeline() {
        timelineGeneration &+= 1
        previousTime = nil
        reportedMissingFood = false
        for node in sprites.values { node.removeFromParent() }
        sprites.removeAll(); masks.removeAll(); framePaths.removeAll(); item.isHidden = true
        render()
    }
    @discardableResult public func playMoodTransition(from: PetMood, to: PetMood) -> Bool {
        guard [.idle,.stateUp,.stateDown].contains(requestedAction) else { return false }
        let source=transitionTarget == nil ? from : mood
        guard source != to else {
            if transitionTarget != nil { play(.idle,mood:to) }
            return false
        }
        transitionSteps=PetMoodTransition.steps(from:source,to:to).filter { step in
            let available=manifest.clips.contains { $0.action == step.action && $0.mood == step.mood }
            if !available { onDiagnostic?("状态过渡缺失，跳过：\(step.action.rawValue)/\(step.mood.rawValue)") }
            return available
        }
        transitionTarget=to
        guard !transitionSteps.isEmpty else { transitionTarget=nil;return false }
        installNextTransition()
        return true
    }
    private func installNextTransition() {
        let step=transitionSteps.removeFirst()
        requestedAction=step.action;mood=step.mood;requestedGraphID=nil;isFinishingActivity=false
        let clip=manifest.clips.first { $0.action == step.action && $0.mood == step.mood }!
        timeline=AnimationTimeline(clip:clip.selectingVariants(random:&random),looping:false)
        installTimeline()
    }
    public var isMovementAnimation:Bool { timeline.map { [.walkLeft,.walkRight,.climb].contains($0.clip.action) } ?? false }
    public var currentPhase:AnimationPhase? { timeline?.stage.phase }
    public func playMovement(_ action:PetAction,graphID:String,mood:PetMood) {
        sideHideMain=nil;sideHideReturning=false;raisedCycles=nil;fidgetCycles=nil;specialIdle=nil;specialReturning=false;playbackMood=nil
        transitionSteps=[];transitionTarget=nil;isFinishingActivity=false
        requestedAction=action;requestedGraphID=graphID;self.mood=mood
        let clip=manifest.clips.first { $0.action==action && $0.graphID==graphID && $0.mood==mood }
            ?? manifest.clips.first { $0.action==action && $0.graphID==graphID && $0.mood == .normal }
            ?? manifest.resolve(action:action == .climb ? .idle : action,mood:mood)
        if clip.graphID != graphID || clip.mood != mood { onDiagnostic?("移动动画回退：\(graphID)/\(mood.rawValue)") }
        guard [.walkLeft,.walkRight,.climb].contains(clip.action) else { play(.idle,mood:mood);return }
        timeline=AnimationTimeline(clip:clip.selectingVariants(random:&random),looping:true);installTimeline()
    }
    @discardableResult public func playSideHide(graphID:String,mood:PetMood) -> Bool {
        guard let clip=manifest.clips.first(where: { $0.action == .sideHide && $0.graphID == graphID && $0.mood == mood })
            ?? manifest.clips.first(where: { $0.action == .sideHide && $0.graphID == graphID && $0.mood == .normal }) else {
            onDiagnostic?("侧挂动画缺失：\(graphID)/\(mood.rawValue)");play(.idle,mood:mood);return false
        }
        transitionSteps=[];transitionTarget=nil;isFinishingActivity=false;raisedCycles=nil;fidgetCycles=nil;specialIdle=nil;specialReturning=false;playbackMood=nil
        requestedAction = .sideHide;requestedGraphID=graphID;self.mood=mood
        if clip.mood != mood { onDiagnostic?("侧挂状态回退：\(graphID)/\(mood.rawValue)") }
        sideHideMain=clip;sideHideReturning=false
        timeline=AnimationTimeline(clip:clip.selectingVariants(random:&random),looping:true);installTimeline()
        return requestedAction == .sideHide
    }
    public func setSideHideHovered(_ hovered:Bool) {
        guard requestedAction == .sideHide,let main=sideHideMain,let graph=main.graphID else { return }
        if hovered {
            guard requestedGraphID == graph || sideHideReturning else { return }
            let rise=graph+".rise"
            guard let clip=manifest.clips.first(where: { $0.action == .sideHide && $0.graphID == rise && $0.mood == mood })
                ?? manifest.clips.first(where: { $0.action == .sideHide && $0.graphID == rise && $0.mood == .normal }) else {
                onDiagnostic?("侧挂探头动画缺失：\(rise)");return
            }
            if clip.mood != mood { onDiagnostic?("侧挂探头状态回退：\(rise)/\(mood.rawValue)") }
            sideHideReturning=false;requestedGraphID=rise
            timeline=AnimationTimeline(clip:clip.selectingVariants(random:&random),looping:true);installTimeline()
        } else if requestedGraphID == graph+".rise",!sideHideReturning,let clip=timeline?.clip {
            sideHideReturning=true
            installSideHideEnd(clip)
        }
    }
    private func installSideHideEnd(_ clip:AnimationClip) {
        let end=clip.stages.filter { $0.phase == .end }
        if end.isEmpty {
            if sideHideReturning { restoreSideHideLoop() }
            else { let completed=requestedAction;play(.idle,mood:mood);onActionFinished?(completed) }
            return
        }
        requestedGraphID=clip.graphID
        timeline=AnimationTimeline(clip:AnimationClip(graphID:clip.graphID,action:clip.action,mood:clip.mood,stages:end),looping:false)
        installTimeline()
    }
    private func restoreSideHideLoop() {
        guard let main=sideHideMain else { return }
        sideHideReturning=false;requestedGraphID=main.graphID
        let loop=main.stages.filter { $0.phase == .loop }
        timeline=AnimationTimeline(clip:AnimationClip(graphID:main.graphID,action:main.action,mood:main.mood,stages:loop.isEmpty ? main.stages:loop),looping:true)
        installTimeline()
    }
    public func finishSideHide() {
        guard requestedAction == .sideHide,let main=sideHideMain else { return }
        // Recovery from Main or Rise always plays Main C directly.
        sideHideMain=nil;sideHideReturning=false;raisedCycles=nil;fidgetCycles=nil;specialIdle=nil;specialReturning=false;installSideHideEnd(main)
    }
    public func playDoze(mood:PetMood) {
        play(.sleep,mood:mood)
        fidgetCycles=PetIdleCycles(limit:timeline?.clip.idleLoopLimit ?? 20)
    }
    @discardableResult public func playSpecialIdle(mood:PetMood) -> Bool {
        guard mood != .ill,let clip=specialClip(graphID:"state.one",mood:mood) else { _=playRandomFidget(mood:mood);return false }
        play(.idle,mood:mood)
        specialIdle=PetSpecialIdle(limit:clip.idleLoopLimit ?? 10)
        installSpecial(clip,loopOnly:false)
        return requestedAction == .specialIdle
    }
    private func specialClip(graphID:String,mood:PetMood) -> AnimationClip? {
        guard mood != .ill else { return nil }
        return manifest.clips.first { $0.action == .specialIdle && $0.graphID == graphID && $0.mood == mood }
            ?? manifest.clips.first { $0.action == .specialIdle && $0.graphID == graphID && $0.mood == .normal }
    }
    private func installSpecial(_ clip:AnimationClip,loopOnly:Bool) {
        requestedAction = .specialIdle;requestedGraphID=clip.graphID;self.mood=clip.mood
        var chosen=clip.selectingVariants(random:&random)
        if loopOnly { chosen.stages=chosen.stages.filter { $0.phase == .loop } }
        guard !chosen.stages.isEmpty else { play(.idle,mood:mood);onActionFinished?(.specialIdle);return }
        timeline=AnimationTimeline(clip:chosen,looping:true);installTimeline()
    }
    @discardableResult public func playRandomFidget(mood:PetMood) -> Bool {
        let choices=manifest.fidgetCandidates(mood:mood)
        guard !choices.isEmpty else { return false }
        let value=random.unit(),unit=value.isFinite ? min(1.0.nextDown,max(0,value)):0
        guard let graph=choices[Int(unit*Double(choices.count))].graphID else { return false }
        playFidget(graphID:graph,mood:mood);return true
    }
    public func playFidget(graphID: String, mood: PetMood) {
        sideHideMain=nil;sideHideReturning=false;raisedCycles=nil;fidgetCycles=nil;specialIdle=nil;specialReturning=false;playbackMood=nil
        transitionSteps=[];transitionTarget=nil
        isFinishingActivity=false;requestedAction = .fidget;requestedGraphID=graphID;self.mood=mood
        let clip=manifest.resolveFidget(graphID:graphID,mood:mood) ?? manifest.resolve(action:.idle,mood:mood)
        if clip.graphID != graphID || clip.mood != mood { onDiagnostic?("自主待机回退：\(graphID)/\(mood.rawValue)") }
        fidgetCycles=clip.idleLoopLimit.map { PetIdleCycles(limit:$0) }
        timeline=AnimationTimeline(clip:clip.selectingVariants(random:&random),looping:fidgetCycles != nil);installTimeline()
    }
    public func playActivity(graphID: String, mood: PetMood) {
        sideHideMain=nil;sideHideReturning=false;raisedCycles=nil;fidgetCycles=nil;specialIdle=nil;specialReturning=false;playbackMood=nil
        transitionSteps=[];transitionTarget=nil
        isFinishingActivity=false;requestedAction = .activity;requestedGraphID=graphID;self.mood=mood
        let clip=manifest.resolveActivity(graphID:graphID,mood:mood)
        if clip.graphID != graphID || clip.mood != mood { onDiagnostic?("活动动画回退：\(graphID)/\(mood.rawValue)") }
        timeline=AnimationTimeline(clip:clip.selectingVariants(random:&random),looping:true);installTimeline()
    }
    @discardableResult public func restoreBase(state: PetState, catalog: PetCatalog, force: Bool = false) -> Bool {
        guard force || !isFinishingActivity else { return false }
        let base=PetPresentation(state:state,catalog:catalog)
        if let graph=base.graphID { playActivity(graphID:graph,mood:state.mood) }
        else { play(base.action,mood:state.mood) }
        return true
    }
    public func setFoodImage(path: String?) {
        foodPath=nil;item.texture=nil;item.isHidden=true;reportedMissingFood=false
        guard let path else { return }
        guard PetCatalog.safePath(path), path.hasPrefix("items/"), path.hasSuffix(".png") else { onDiagnostic?("拒绝不合法食物图片路径。");return }
        if let entry=cache.get(AnimationFrame(path:path,duration:1,width:1,height:1),root:assetRoot) { foodPath=path;item.texture=entry.texture }
        else { onDiagnostic?("物品图片缺失或无法解码：\(path)") }
    }
    public func setTextureResolution(pixelWidth: Int) {
        let target = min(1024, max(256, ((pixelWidth + 127) / 128) * 128))
        guard cache.pixelWidth != target else { return }
        releaseTextures(); cache.pixelWidth = target; render()
    }
    @discardableResult public func finishActivity() -> Bool {
        guard requestedAction == .activity else { return false }
        isFinishingActivity = true; timeline?.requestFinish(); return true
    }
    public func finishAction() { specialIdle=nil;specialReturning=false;fidgetCycles=nil;timeline?.requestFinish() }
    public func resetTiming() { previousTime = nil }
    public func releaseTextures() {
        for node in sprites.values { node.texture = nil }
        framePaths.removeAll(); masks.removeAll(); cache.clear();item.texture=nil;item.isHidden=true
    }
    nonisolated public override func update(_ currentTime: TimeInterval) {
        MainActor.assumeIsolated { advance(currentTime) }
    }
    private func advance(_ currentTime: TimeInterval) {
        defer { previousTime = currentTime }
        if let previousTime {
            let delta=min(max(currentTime-previousTime,0),0.25)
            let previousPhase=timeline?.stage.phase
            let previousLoops=timeline.map { $0.stage.phase == .loop ? Int(($0.elapsed+delta)/$0.stage.duration):0 } ?? 0
            if requestedAction == .idle, let timeline, timeline.stage.phase == .loop {
                let cycles=Int((timeline.elapsed+delta)/timeline.stage.duration)
                for _ in 0..<cycles { onIdleCycle?() }
            }
            if [.fidget,.sleep].contains(requestedAction),let current=timeline,current.stage.phase == .loop,fidgetCycles != nil {
                let cycles=Int((current.elapsed+delta)/current.stage.duration)
                for _ in 0..<cycles {
                    if fidgetCycles?.continueAfterLoop(random:&random) != true { timeline?.requestFinish();break }
                }
            }
            if requestedAction == .specialIdle,let current=timeline,current.stage.phase == .loop,specialIdle != nil {
                let loops=Int((current.elapsed+delta)/current.stage.duration)
                for _ in 0..<loops {
                    switch specialIdle!.afterLoop(random:&random) {
                    case .continueLoop:break
                    case .enterTwo:
                        guard let clip=specialClip(graphID:"state.two",mood:playbackMood ?? mood) else { specialIdle=nil;timeline?.requestFinish();break }
                        installSpecial(clip,loopOnly:false);return
                    case .returnOne:specialReturning=true;timeline?.requestFinish()
                    case .finish:specialIdle=nil;timeline?.requestFinish()
                    }
                    if specialReturning || specialIdle == nil { break }
                }
            }
            if requestedAction == .pinch,let current=timeline,current.clip.action == .pinch,current.stage.phase == .loop {
                let generation=timelineGeneration
                let cycles=Int((current.elapsed+delta)/current.stage.duration)
                for _ in 0..<cycles {
                    let held=onPinchLoop?() ?? false
                    if generation != timelineGeneration { return }
                    if !held { timeline?.requestFinish();break }
                }
            }
            if isMovementAnimation,let current=timeline,current.stage.phase == .loop {
                let generation=timelineGeneration
                let cycles=Int((current.elapsed+delta)/current.stage.duration)
                for _ in 0..<cycles {
                    let keepGoing=onMovementLoop?() ?? true
                    if generation != timelineGeneration { return }
                    if !keepGoing { timeline?.requestFinish();break }
                }
            }
            timeline?.advance(delta)
            if timeline?.finished == false,let phase=timeline?.stage.phase,phase != previousPhase || (phase == .loop && previousLoops>0) {
                refreshPlayback(phase:phase)
            }
        }
        if timeline?.finished == true {
            if requestedAction == .specialIdle,specialReturning,let clip=specialClip(graphID:"state.one",mood:playbackMood ?? mood) {
                specialReturning=false;installSpecial(clip,loopOnly:true);return
            }
            if requestedAction == .raised,let cycle=raisedCycles,let clip=timeline?.clip {
                if cycle<2 {
                    let target=playbackMood ?? mood
                    let raw=manifest.resolvePlayback(action:.raised,graphID:"raised.dynamic",mood:target) ?? clip
                    raisedCycles=cycle+1;mood=raw.mood;timeline=AnimationTimeline(clip:raw.selectingVariant(phase:.loop,random:&random),looping:false);installTimeline()
                } else { play(.raised,mood:playbackMood ?? mood) }
                return
            }
            if sideHideReturning,sideHideMain != nil { restoreSideHideLoop();return }
            let completed = requestedAction
            if !transitionSteps.isEmpty { installNextTransition();return }
            let settledMood=transitionTarget ?? playbackMood ?? mood
            play(.idle, mood: settledMood); onActionFinished?(completed)
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
                    if requestedAction != .idle {
                        let completed=requestedAction, target=transitionTarget
                        play(.idle,mood:target ?? mood)
                        if target != nil || [.walkLeft,.walkRight,.climb,.sideHide,.raised,.pinch,.specialIdle].contains(completed) { onActionFinished?(completed) }
                        return
                    }
                }
            }
        }
        if let food = stage.food(at: elapsed), food.visible {
            if item.texture == nil, let path=foodPath { setFoodImage(path:path) }
            guard let texture = item.texture else {
                item.isHidden = true
                if !reportedMissingFood {
                    onDiagnostic?("进食动画未绑定可用物品图片，已隐藏物品层。")
                    reportedMissingFood = true
                }
                return
            }
            let imageSize=texture.size()
            item.size=CGSize(width:food.width,height:food.width*imageSize.height/max(1,imageSize.width));item.alpha=food.opacity
            item.position = CGPoint(x: food.x + food.width / 2, y: size.height - food.y - item.size.height / 2)
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
