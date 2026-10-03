// SPDX-License-Identifier: Apache-2.0
import XCTest
import CoreGraphics
@testable import PetRendering
final class PetMovementAreaTests:XCTestCase {
    let primary=CGRect(x:0,y:0,width:1000,height:800)
    let secondary=CGRect(x:-800,y:0,width:800,height:600)
    let pet=CGRect(x:-600,y:100,width:200,height:200)
    func testPrimaryAndCurrentScreen() {
        XCTAssertEqual(PetMovementArea.resolve(mode:.primary,custom:nil,pet:pet,screens:[primary,secondary]).rect,primary)
        XCTAssertEqual(PetMovementArea.resolve(mode:.current,custom:nil,pet:pet,screens:[primary,secondary]).rect,secondary)
    }
    func testCustomNegativeCoordinatesAndClipping() {
        let custom=CGRect(x:-900,y:50,width:800,height:400)
        let result=PetMovementArea.resolve(mode:.custom,custom:custom,pet:pet,screens:[primary,secondary])
        XCTAssertEqual(result.rect,CGRect(x:-800,y:50,width:700,height:400));XCTAssertTrue(result.adjusted)
        let inside=CGRect(x:-700,y:50,width:600,height:400)
        let same=PetMovementArea.resolve(mode:.custom,custom:inside,pet:pet,screens:[primary,secondary])
        XCTAssertEqual(same.rect,inside);XCTAssertFalse(same.adjusted)
    }
    func testUnavailableAndTooSmallAreasFallbackWithoutChangingPreference() {
        for custom in [CGRect(x:3000,y:0,width:400,height:400),CGRect(x:-600,y:100,width:100,height:100),CGRect(x:0,y:0,width:0,height:400),CGRect(x:Double.nan,y:0,width:400,height:400)] {
            let result=PetMovementArea.resolve(mode:.custom,custom:custom,pet:pet,screens:[primary,secondary])
            XCTAssertEqual(result.rect,secondary);XCTAssertTrue(result.adjusted)
        }
        let saved=CGRect(x:-700,y:50,width:600,height:400)
        XCTAssertEqual(PetMovementArea.resolve(mode:.custom,custom:saved,pet:pet,screens:[primary]).rect,primary)
        XCTAssertEqual(PetMovementArea.resolve(mode:.custom,custom:saved,pet:pet,screens:[primary,secondary]).rect,saved)
    }
    func testNoScreenAndInvalidScreen() {
        XCTAssertNil(PetMovementArea.resolve(mode:.current,custom:nil,pet:pet,screens:[]).rect)
        XCTAssertNil(PetMovementArea.resolve(mode:.primary,custom:nil,pet:pet,screens:[.null,.zero]).rect)
    }
    func testPhysicalFallbackMustContainPet() {
        let small=CGRect(x:0,y:0,width:300,height:300),large=CGRect(x:300,y:0,width:1000,height:800)
        let bigPet=CGRect(x:-200,y:-200,width:500,height:500)
        for mode in PetMovementAreaMode.allCases {
            let result=PetMovementArea.resolve(mode:mode,custom:nil,pet:bigPet,screens:[small,large])
            XCTAssertEqual(result.rect,large);XCTAssertTrue(result.adjusted)
        }
        XCTAssertNil(PetMovementArea.resolve(mode:.current,custom:nil,pet:bigPet,screens:[small]).rect)
    }
    func testCrossScreenAreaUsesLargestUsableIntersection() {
        let custom=CGRect(x:-700,y:50,width:1500,height:500)
        XCTAssertEqual(PetMovementArea.resolve(mode:.custom,custom:custom,pet:pet,screens:[primary,secondary]).rect,CGRect(x:0,y:50,width:800,height:500))
    }
}
