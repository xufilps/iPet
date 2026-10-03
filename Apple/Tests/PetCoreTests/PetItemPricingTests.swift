// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetItemPricingTests:XCTestCase {
    func testOriginalFormulaThresholdAndTruncation() throws {
        let item=ItemDefinition(id:"mixed",name:"混合",price:1,strength:50,food:20,drink:30,feeling:12,health:3,affection:2,experience:90)
        XCTAssertEqual(PetItemPricing.recommendedPrice(item),43.66666666666667,accuracy:1e-10)
        XCTAssertEqual(try PetItemPricing.catalog(PetCatalog(items:[item]),enabled:true).items[0].price,43)
        var boundary=ItemDefinition(id:"edge",name:"边界",price:(100.0-10)*0.7,health:100)
        XCTAssertFalse(PetItemPricing.isUnderpriced(boundary))
        boundary.price -= 0.001;XCTAssertTrue(PetItemPricing.isUnderpriced(boundary))
        let zero=ItemDefinition(id:"zero",name:"零价",price:0,health:15.7)
        XCTAssertEqual(try PetItemPricing.catalog(PetCatalog(items:[zero]),enabled:true).items[0].price,15)
        let negative=ItemDefinition(id:"negative",name:"代价",price:0,health:-20)
        XCTAssertFalse(PetItemPricing.isUnderpriced(negative))
    }
    func testOriginalIntegerExperienceDivisionAndUnsupportedFraction() throws {
        for (experience,recommended) in [(5.0,15.833333333333334),(-5.0,15.166666666666666)] {
            let item=ItemDefinition(id:"exp",name:"经验",price:0,health:15.5,experience:experience)
            XCTAssertEqual(PetItemPricing.recommendedPrice(item),recommended,accuracy:1e-10)
            XCTAssertEqual(try PetItemPricing.catalog(PetCatalog(items:[item]),enabled:true).items[0].price,15)
        }
        let source=PetCatalog(items:[ItemDefinition(id:"fraction",name:"非整数",price:0,health:15.5,experience:5.5)])
        XCTAssertThrowsError(try PetItemPricing.catalog(source,enabled:true))
        XCTAssertEqual(try PetItemPricing.catalog(source,enabled:false),source)
    }
    func testActualCatalogueOnlyTwoItemsChange() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source=try PetCatalog.load(from:root.appendingPathComponent("Resources/PetAssets/gameplay.json"))
        let priced=try PetItemPricing.catalog(source,enabled:true)
        let changes=zip(source.items,priced.items).filter { $0.price != $1.price }
        XCTAssertEqual(changes.map { $1.name },["Shiori v5","Shiori v7"])
        XCTAssertEqual(changes.map { $1.price },[619,927])
        XCTAssertEqual(priced.activities,source.activities);XCTAssertEqual(priced.packages,source.packages)
        XCTAssertEqual(try PetItemPricing.catalog(source,enabled:false),source)
    }
    func testEngineSwitchesWithoutResettingStateAndUsesAdjustedTransactionPrice() throws {
        let item=ItemDefinition(id:"i",name:"物品",price:1,health:100)
        var state=PetState();state.money=1000
        let engine=PetEngine(state:state,catalog:PetCatalog(items:[item]))
        let before=engine.state
        try engine.configureItemPricing(enabled:true)
        XCTAssertEqual(engine.state,before)
        XCTAssertTrue(engine.perform(.buyItem("i",mode:.inventory)).accepted)
        XCTAssertEqual(engine.state.money,900);XCTAssertEqual(engine.state.progress?.spent,100)
        let purchased=engine.state
        try engine.configureItemPricing(enabled:false)
        XCTAssertEqual(engine.catalog.items[0].price,1);XCTAssertEqual(engine.state,purchased)
        try engine.configureItemPricing(enabled:true)
        XCTAssertEqual(engine.catalog.items[0].price,100);XCTAssertEqual(engine.state,purchased)
        XCTAssertEqual(engine.state.inventoryMetadata?["i"]?.price,100)
    }
    func testUnsafeCandidateIsRejectedAtomically() throws {
        let source=PetCatalog(items:[ItemDefinition(id:"bad",name:"极值",price:0,affection:3e8)])
        try source.validate()
        let engine=PetEngine(catalog:source);let before=engine.state
        XCTAssertThrowsError(try engine.configureItemPricing(enabled:true))
        XCTAssertEqual(engine.catalog,source);XCTAssertFalse(engine.automaticItemPricing)
        XCTAssertEqual(engine.state,before)
    }
    func testPricingDoesNotInterruptActiveSessionOrPendingEvents() throws {
        let work=ActivityDefinition(id:"w",name:"工作",graphID:"work",kind:.work,durationSeconds:600,moneyBase:1,strengthFood:0,strengthDrink:0,feeling:0,finishBonus:0)
        let engine=PetEngine(catalog:PetCatalog(activities:[work],items:[ItemDefinition(id:"i",name:"物品",price:1,health:100)]))
        XCTAssertTrue(engine.perform(.startActivity("w")).accepted)
        let active=engine.state
        try engine.configureItemPricing(enabled:true);XCTAssertEqual(engine.state,active)
        XCTAssertTrue(engine.perform(.stopActivity).accepted)
        try engine.configureItemPricing(enabled:false)
        XCTAssertTrue(engine.drainEvents().contains { if case .activityStopped = $0 { return true };return false })
    }
}
