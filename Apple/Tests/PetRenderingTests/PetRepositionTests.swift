// SPDX-License-Identifier: Apache-2.0
import XCTest
import CoreGraphics
@testable import PetRendering
final class PetRepositionTests:XCTestCase {
    let area=CGRect(x:0,y:0,width:1000,height:800)
    func testStrictQuarterThresholdOnAllEdges() {
        for pet in [CGRect(x:-50,y:100,width:200,height:200),CGRect(x:850,y:100,width:200,height:200),CGRect(x:100,y:-50,width:200,height:200),CGRect(x:100,y:650,width:200,height:200)] {
            XCTAssertFalse(PetReposition.needsCorrection(pet:pet,area:area,primary:area))
        }
        for pet in [CGRect(x:-51,y:100,width:200,height:200),CGRect(x:851,y:100,width:200,height:200),CGRect(x:100,y:-51,width:200,height:200),CGRect(x:100,y:651,width:200,height:200)] {
            XCTAssertTrue(PetReposition.needsCorrection(pet:pet,area:area,primary:area))
        }
    }
    func testCorrectionOnlyChangesEligibleAxes() {
        let frames=[CGRect(x:-51,y:-30,width:200,height:200),CGRect(x:851,y:651,width:200,height:200),CGRect(x:100,y:-51,width:200,height:200)]
        let expected=[CGRect(x:0,y:-30,width:200,height:200),CGRect(x:800,y:600,width:200,height:200),CGRect(x:100,y:0,width:200,height:200)]
        for (p,e) in zip(frames,expected) { XCTAssertEqual(PetReposition.corrected(pet:p,area:area,primary:area),e) }
    }
    func testOppositeDistanceUsesPrimarySizeAndStrictGuard() {
        let p=CGRect(x:-100,y:100,width:200,height:200)
        XCTAssertFalse(PetReposition.needsCorrection(pet:p,area:area,primary:CGRect(x:0,y:0,width:900,height:800)))
        XCTAssertTrue(PetReposition.needsCorrection(pet:p,area:area,primary:CGRect(x:0,y:0,width:901,height:800)))
        XCTAssertEqual(PetReposition.corrected(pet:p,area:area,primary:CGRect(x:0,y:0,width:900,height:800)),p)
    }
    func testRaisedPlacementDisablesUntilPositionReturns() {
        var recovery=PetReposition()
        let outside=CGRect(x:100,y:-80,width:200,height:200)
        recovery.raised(pet:outside,area:area,primary:area);XCTAssertFalse(recovery.isActive)
        XCTAssertEqual(recovery.stop(pet:outside,area:area,primary:area),outside);XCTAssertFalse(recovery.isActive)
        let inside=CGRect(x:100,y:0,width:200,height:200)
        XCTAssertEqual(recovery.stop(pet:inside,area:area,primary:area),inside);XCTAssertTrue(recovery.isActive)
        XCTAssertEqual(recovery.stop(pet:outside,area:area,primary:area),inside);XCTAssertTrue(recovery.isActive)
    }
    func testResetRestoresCorrectionAndNegativeAreaCoordinates() {
        var recovery=PetReposition()
        let screen=area.offsetBy(dx:-1000,dy:-400),p=CGRect(x:-900,y:-480,width:200,height:200)
        recovery.raised(pet:p,area:screen,primary:area);XCTAssertFalse(recovery.isActive)
        recovery.reset();XCTAssertTrue(recovery.isActive)
        XCTAssertEqual(recovery.stop(pet:p,area:screen,primary:area),CGRect(x:-900,y:-400,width:200,height:200))
    }
    func testInvalidGeometryDoesNotMove() {
        let p=CGRect(x:Double.nan,y:0,width:200,height:200)
        XCTAssertFalse(PetReposition.needsCorrection(pet:p,area:area,primary:area))
        XCTAssertEqual(PetReposition.corrected(pet:area,area:.null,primary:area),area)
    }
}
