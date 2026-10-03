// SPDX-License-Identifier: Apache-2.0
import XCTest
import CoreGraphics
@testable import PetRendering
final class PetScreenChangeTests:XCTestCase {
    let left=PetScreenChange.Display(id:"left",frame:CGRect(x:-800,y:0,width:800,height:600))
    let right=PetScreenChange.Display(id:"right",frame:CGRect(x:0,y:0,width:1000,height:800))
    let pet=CGRect(x:-500,y:100,width:200,height:200)
    func testPersistedIdentityRejectsTransientNumericIDs() {
        let uuid="A65F8780-AFBA-4C1B-972F-1A18511E0381"
        XCTAssertEqual(PetScreenChange.persistedIdentity(uuid.lowercased()),uuid)
        for raw in [nil,"","1","123456789","unknown"] as [String?] { XCTAssertNil(PetScreenChange.persistedIdentity(raw)) }
    }
    func testCrossDisplayActivatesWithoutMovingPet() {
        XCTAssertEqual(PetScreenChange.target(enabled:true,blocked:false,activeID:"right",pet:pet,displays:[left,right])?.id,"left")
        XCTAssertEqual(PetScreenChange.target(enabled:true,blocked:false,activeID:"right",pet:pet,displays:[left,right])?.frame,left.frame)
    }
    func testSameDisplayAndDisabledAndBlockedDoNotActivate() {
        XCTAssertNil(PetScreenChange.target(enabled:true,blocked:false,activeID:"left",pet:pet,displays:[left,right]))
        XCTAssertNil(PetScreenChange.target(enabled:false,blocked:false,activeID:"right",pet:pet,displays:[left,right]))
        XCTAssertNil(PetScreenChange.target(enabled:true,blocked:true,activeID:"right",pet:pet,displays:[left,right]))
    }
    func testUnavailableOrInvalidDisplayCannotReplaceSavedRegion() {
        XCTAssertNil(PetScreenChange.target(enabled:true,blocked:false,activeID:"right",pet:pet,displays:[]))
        XCTAssertNil(PetScreenChange.target(enabled:true,blocked:false,activeID:"right",pet:pet.offsetBy(dx:-3000,dy:0),displays:[left,right]))
        XCTAssertNil(PetScreenChange.target(enabled:true,blocked:false,activeID:"right",pet:pet,displays:[.init(id:"",frame:left.frame)]))
        XCTAssertNil(PetScreenChange.target(enabled:true,blocked:false,activeID:"right",pet:pet,displays:[.init(id:"invalid",frame:.null)]))
    }
    func testMissingIdentityOnMainIntersectionDoesNotSelectNeighbor() {
        let unknown=PetScreenChange.Display(id:"",frame:left.frame)
        let straddling=CGRect(x:-180,y:100,width:200,height:200)
        XCTAssertNil(PetScreenChange.target(enabled:true,blocked:false,activeID:"old",pet:straddling,displays:[unknown,right]))
    }
    func testSmallDisplayDoesNotActivateOrChooseDistantOne() {
        let small=PetScreenChange.Display(id:"small",frame:CGRect(x:-500,y:100,width:100,height:100))
        XCTAssertNil(PetScreenChange.target(enabled:true,blocked:false,activeID:"right",pet:pet,displays:[small,right]))
    }
}
