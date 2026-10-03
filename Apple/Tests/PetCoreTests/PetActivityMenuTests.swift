// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetActivityMenuTests:XCTestCase {
    func catalog()->PetCatalog {
        PetCatalog(activities:[
            ActivityDefinition(id:"play",name:"玩",graphID:"Play",kind:.play,durationSeconds:60,moneyBase:1,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0),
            ActivityDefinition(id:"work",name:"工作",graphID:"Work",kind:.work,durationSeconds:60,levelLimit:5,moneyBase:1,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0),
            ActivityDefinition(id:"study",name:"学习",graphID:"Study",kind:.study,durationSeconds:60,moneyBase:1,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0)])
    }
    func testIdentityOrderAndLevelGating() {
        let items=PetActivityMenu.items(catalog:catalog(),state:PetState(),enabled:true)
        XCTAssertEqual(items.map(\.id),["play","work","study"])
        XCTAssertEqual(items.map(\.kind),[.play,.work,.study])
        XCTAssertEqual(items.map(\.isEnabled),[true,false,true])
        XCTAssertEqual(items[1].levelLimit,5)
        XCTAssertTrue(PetActivityMenu.items(catalog:PetCatalog(),state:PetState(),enabled:true).isEmpty)
    }
    func testIllAndExternalSafetyGateDisableAllChoices() {
        var state=PetState();state.health=0
        XCTAssertTrue(PetActivityMenu.items(catalog:catalog(),state:state,enabled:true).allSatisfy { !$0.isEnabled })
        let gates=[
            PetActivityMenuAccess(writable:false,saveFailed:false,busy:false,simulationEnabled:true,visible:true,suspended:false),
            PetActivityMenuAccess(writable:true,saveFailed:true,busy:false,simulationEnabled:true,visible:true,suspended:false),
            PetActivityMenuAccess(writable:true,saveFailed:false,busy:true,simulationEnabled:true,visible:true,suspended:false),
            PetActivityMenuAccess(writable:true,saveFailed:false,busy:false,simulationEnabled:false,visible:true,suspended:false),
            PetActivityMenuAccess(writable:true,saveFailed:false,busy:false,simulationEnabled:true,visible:false,suspended:false),
            PetActivityMenuAccess(writable:true,saveFailed:false,busy:false,simulationEnabled:true,visible:true,suspended:true)]
        for gate in gates {
            XCTAssertFalse(gate.allowsSelection)
            XCTAssertTrue(PetActivityMenu.items(catalog:catalog(),state:PetState(),enabled:gate.allowsSelection).allSatisfy { !$0.isEnabled })
        }
    }
    func testCurrentActivityIsExplicitStopAndFreshStateIsReevaluated() {
        var state=PetState();state.activity=ActivitySession(activityID:"study")
        let items=PetActivityMenu.items(catalog:catalog(),state:state,enabled:true)
        XCTAssertEqual(items.filter(\.isCurrent).map(\.id),["study"])
        state.experience=1600
        XCTAssertTrue(PetActivityMenu.items(catalog:catalog(),state:state,enabled:true).first { $0.id=="work" }!.isEnabled)
    }
}
