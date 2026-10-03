import XCTest
@testable import PetCore
final class PetOwnedInventoryTests:XCTestCase {
    private let id="same"
    private var catalog:PetCatalog { PetCatalog(items:[ItemDefinition(id:id,name:"当前商品",price:5,drink:2,experience:4)]) }
    private func state(extra:String="",type:String="Food",count:Int=2) throws -> PetState {
        var state=PetState();state.inventory[id]=count;state.drink=10
        let doc=try PetLegacyLPSDocument.parse(Data("item0:|name#旧商品:|itemtype#\(type):|Price#9:|Type#Drink:|StrengthDrink#12:|Exp#7:|IsSingle#True:|Data#private:|\(extra)".utf8))
        state.inventoryMetadata=[id:try PetInventoryMetadata(legacy:XCTUnwrap(PetLegacyInventoryPreview(document:doc).records[0].item))]
        return state
    }
    func testOwnedParametersWinWhileShopImmediateUsesCatalog() throws {
        let engine=PetEngine(state:try state(),catalog:catalog,wallClock:FixedWallClock())
        XCTAssertTrue(engine.perform(.useItem(id)).accepted);XCTAssertEqual(engine.state.drink,16)
        XCTAssertEqual(engine.state.experience,7);XCTAssertEqual(engine.state.inventory[id],1)
        XCTAssertEqual(engine.lastUsedItem?.name,"旧商品");XCTAssertEqual(engine.lastUsedItem?.category,.drink)
        XCTAssertTrue(engine.perform(.buyItem(id,mode:.useImmediately)).accepted)
        XCTAssertEqual(engine.state.money,95);XCTAssertEqual(engine.state.inventory[id],1)
        XCTAssertEqual(engine.lastUsedItem?.name,"当前商品")
    }
    func testBuyIntoExistingStockPreservesMetadataAndPriceComesFromShop() throws {
        let engine=PetEngine(state:try state(),catalog:catalog)
        let original=engine.state.inventoryMetadata
        XCTAssertTrue(engine.perform(.buyItem(id,mode:.inventory)).accepted)
        XCTAssertEqual(engine.state.money,95);XCTAssertEqual(engine.state.inventory[id],3)
        XCTAssertEqual(engine.state.inventoryMetadata,original)
    }
    func testLastUnitClearsOldParametersAndNextPurchaseCapturesNewCatalog() throws {
        let engine=PetEngine(state:try state(count:1),catalog:catalog)
        XCTAssertTrue(engine.perform(.useItem(id)).accepted);XCTAssertNil(engine.state.inventoryMetadata?[id])
        XCTAssertEqual(engine.lastUsedItem?.name,"旧商品")
        XCTAssertTrue(engine.perform(.buyItem(id,mode:.inventory)).accepted)
        XCTAssertEqual(engine.state.inventoryMetadata?[id]?.name,"当前商品")
        XCTAssertEqual(engine.state.inventoryDefinition(id,catalog:catalog)?.drink,2)
    }
    func testCannotUseDisabledOrOpaqueMetadataEvenWithSameCatalogID() throws {
        for state in [try state(extra:"CanUse#False:|"),try state(type:"Plugin")] {
            let engine=PetEngine(state:state,catalog:catalog);let before=engine.state
            XCTAssertFalse(engine.perform(.useItem(id)).accepted);XCTAssertEqual(engine.state,before)
            XCTAssertEqual(engine.useItems(id:id,count:2).used,0)
        }
    }
    func testNewPurchaseSnapshotSurvivesChangedCatalogAndJSONRoundTrip() throws {
        let engine=PetEngine(catalog:catalog);XCTAssertTrue(engine.perform(.buyItem(id,mode:.inventory)).accepted)
        let decoded=try JSONDecoder().decode(PetSaveDocument.self,from:JSONEncoder().encode(PetSaveDocument(state:engine.state)))
        let changed=PetCatalog(items:[ItemDefinition(id:id,name:"后来改价",price:500,drink:100)])
        let restored=PetEngine(state:decoded.state,catalog:changed)
        XCTAssertEqual(restored.state.inventoryDefinition(id,catalog:changed)?.drink,2)
        XCTAssertTrue(restored.perform(.useItem(id)).accepted);XCTAssertEqual(restored.state.experience,4)
    }
    func testInvalidEffectsRollBackCountAndMetadata() throws {
        var state=try state();state.storedDrink=9999
        let engine=PetEngine(state:state,catalog:catalog);let before=engine.state
        XCTAssertFalse(engine.perform(.useItem(id)).accepted);XCTAssertEqual(engine.state,before)
    }
    func testFavoriteAndVisibilityUseSavedMetadataWithoutChangingGlobalValue() throws {
        var state=try state(extra:"Visibility#False:|")
        state.inventory["other"]=1
        let engine=PetEngine(state:state,catalog:catalog)
        XCTAssertTrue(engine.setInventoryFavorite(id:id,favorite:true).accepted)
        XCTAssertEqual(engine.state.inventoryMetadata?[id]?.star,true)
        let result=PetInventoryQuery(favoritesOnly:true).evaluate(inventory:engine.state.inventory,catalog:catalog,metadata:engine.state.inventoryMetadata ?? [:])
        XCTAssertTrue(result.ids.isEmpty);XCTAssertEqual(result.totalCount,3)
        XCTAssertEqual(result.knownValue,18);XCTAssertEqual(result.unpricedCount,1)
    }
    func testPresentedRowMultiplierUsesItsOwnCategory() throws {
        let state=try state(),now=Date(timeIntervalSince1970:1_000_000)
        let shop=ItemDefinition(id:id,name:"当前礼品",category:.gift,price:5)
        let owned=try XCTUnwrap(state.inventoryDefinition(id,catalog:catalog))
        let expiry=now.addingTimeInterval(4*3600)
        XCTAssertEqual(PetItemRules.multiplier(item:shop,expiry:expiry,now:now),0.84,accuracy:1e-9)
        XCTAssertEqual(PetItemRules.multiplier(item:owned,expiry:expiry,now:now),0.68,accuracy:1e-9)
    }
    func testFractionalCatalogExperienceIsNotSilentlyTruncatedInSnapshot() {
        let catalog=PetCatalog(items:[ItemDefinition(id:id,name:"fraction",price:1,experience:1.5)])
        let engine=PetEngine(catalog:catalog);let before=engine.state
        XCTAssertFalse(engine.perform(.buyItem(id,mode:.inventory)).accepted);XCTAssertEqual(engine.state,before)
    }
}
