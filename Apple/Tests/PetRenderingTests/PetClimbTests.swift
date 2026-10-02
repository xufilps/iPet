import XCTest
import PetCore
@testable import PetRendering
final class PetClimbTests:XCTestCase {
    func testRecoveryReturnsPartiallyClippedFramesToVisibleScreen() {
        let screen=CGRect(x:-1000,y:50,width:1000,height:900)
        XCTAssertEqual(PetClimbPlan.recovered(pet:CGRect(x:-1072.5,y:300,width:250,height:250),screen:screen),CGRect(x:-1000,y:300,width:250,height:250))
        XCTAssertEqual(PetClimbPlan.recovered(pet:CGRect(x:-92.5,y:850,width:250,height:250),screen:screen),CGRect(x:-250,y:700,width:250,height:250))
    }
    func testOriginalSideAnchorsAndMacYDirection() throws {
        let screen=CGRect(x:-1000,y:50,width:1000,height:900),pet=CGRect(x:-950,y:300,width:250,height:250)
        let up=try XCTUnwrap(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:pet,screen:screen))
        let located=up.located(pet:pet,screen:screen)
        XCTAssertEqual(located.minX,-1072.5);XCTAssertEqual(located.minY,300)
        XCTAssertEqual(up.advance(pet:located,screen:screen,seconds:0.125)?.minY,305)
        let rightPet=CGRect(x:-300,y:300,width:250,height:250)
        let down=try XCTUnwrap(PetClimbPlan.make(left:false,up:false,mood:.normal,pet:rightPet,screen:screen))
        let right=down.located(pet:rightPet,screen:screen)
        XCTAssertEqual(right.minX,-92.5);XCTAssertEqual(down.advance(pet:right,screen:screen,seconds:0.125)?.minY,295)
    }
    func testTriggerCheckAndIllRejection() throws {
        let screen=CGRect(x:0,y:0,width:1000,height:800),pet=CGRect(x:50,y:400,width:250,height:250)
        XCTAssertNotNil(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:pet,screen:screen))
        XCTAssertNil(PetClimbPlan.make(left:true,up:true,mood:.ill,pet:pet,screen:screen))
        XCTAssertNil(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:CGRect(x:51,y:400,width:250,height:250),screen:screen))
        XCTAssertNil(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:CGRect(x:50,y:451,width:250,height:250),screen:screen))
        let up=try XCTUnwrap(PetClimbPlan.make(left:true,up:true,mood:.normal,pet:pet,screen:screen))
        let near=CGRect(x:-72.5,y:499,width:250,height:250)
        XCTAssertEqual(up.advance(pet:near,screen:screen,seconds:0.125)?.minY,500)
        XCTAssertNil(up.advance(pet:CGRect(x:-72.5,y:500,width:250,height:250),screen:screen,seconds:0.125))
    }
    func testTopLocateSpeedAndDistance() throws {
        let screen=CGRect(x:-1000,y:50,width:1000,height:900),pet=CGRect(x:-600,y:650,width:250,height:250)
        let left=try XCTUnwrap(PetClimbPlan.makeTop(left:true,mood:.normal,pet:pet,screen:screen))
        XCTAssertEqual(left.graphID,"climb.top.left");XCTAssertEqual(left.distance,10)
        let located=left.located(pet:pet,screen:screen)
        XCTAssertEqual(located.minY,775)
        XCTAssertEqual(left.advance(pet:located,screen:screen,seconds:0.125)?.minX,-604)
        XCTAssertNil(PetClimbPlan.makeTop(left:true,mood:.normal,pet:CGRect(x:-600,y:649,width:250,height:250),screen:screen))
        XCTAssertNil(PetClimbPlan.makeTop(left:true,mood:.ill,pet:pet,screen:screen))
        let right=try XCTUnwrap(PetClimbPlan.makeTop(left:false,mood:.poor,pet:pet,screen:screen))
        XCTAssertEqual(right.advance(pet:right.located(pet:pet,screen:screen),screen:screen,seconds:0.125)?.minX,-596)
    }
    func testFallVectorAndCoupledBoundary() throws {
        let screen=CGRect(x:0,y:0,width:1000,height:800),pet=CGRect(x:400,y:300,width:250,height:250)
        let left=try XCTUnwrap(PetClimbPlan.makeFall(left:true,mood:.happy,pet:pet,screen:screen))
        XCTAssertEqual(left.graphID,"fall.left");XCTAssertEqual(left.distance,7)
        XCTAssertEqual(left.located(pet:pet,screen:screen),pet)
        XCTAssertEqual(left.advance(pet:pet,screen:screen,seconds:0.125),CGRect(x:393,y:295,width:250,height:250))
        let near=CGRect(x:52,y:100,width:250,height:250)
        let next=try XCTUnwrap(left.advance(pet:near,screen:screen,seconds:0.125))
        XCTAssertEqual(next.minX,50);XCTAssertEqual(next.minY,100-10.0/7,accuracy:0.000001)
        XCTAssertNil(left.advance(pet:next,screen:screen,seconds:0.125))
        XCTAssertNil(PetClimbPlan.makeFall(left:true,mood:.normal,pet:CGRect(x:99,y:300,width:250,height:250),screen:screen))
        XCTAssertNil(PetClimbPlan.makeFall(left:true,mood:.normal,pet:CGRect(x:400,y:99,width:250,height:250),screen:screen))
        XCTAssertNil(PetClimbPlan.makeFall(left:true,mood:.ill,pet:pet,screen:screen))
    }

    func testTopAndFallGraphsStartLoopAndFinish() async throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets")
        let manifest=try PetManifest.load(from:root)
        for graph in ["climb.top.left","climb.top.right","fall.left","fall.right"] {
            for mood in [PetMood.happy,.normal,.poor] {
                let clip=try XCTUnwrap(manifest.clips.first { $0.graphID == graph && $0.mood == mood })
                XCTAssertEqual(clip.stages.map(\.phase),[.start,.loop,.end])
            }
            await MainActor.run {
                let scene=PetScene(manifest:manifest,assetRoot:root)
                scene.playMovement(.climb,graphID:graph,mood:.normal)
                XCTAssertEqual(scene.requestedGraphID,graph);XCTAssertEqual(scene.currentPhase,.start)
                XCTAssertTrue(scene.isMovementAnimation)
                scene.onMovementLoop={ false }
                scene.update(0)
                for step in 1...80 { scene.update(Double(step)*0.25) }
                XCTAssertEqual(scene.requestedAction,.idle)
                XCTAssertFalse(scene.isMovementAnimation)
            }
        }
    }

}
