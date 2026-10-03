import XCTest
@testable import PetCore
final class PetInventoryMetadataTests:XCTestCase {
    private func sample(_ extra:String="",type:String="Food") throws -> PetLegacyInventoryPreview.Item {
        let document=try PetLegacyLPSDocument.parse(Data("item0:|name#旧食物:|itemtype#\(type):|Price#-2.5:|Count#9:|Data#私有/!n:|Desc#描述:|Image#../outside.png:|Star#True:|CanUse#False:|IsSingle#True:|Visibility#False:|Type#Drink:|Exp#7:|Strength#-1.25:|StrengthFood#3.5:|StrengthDrink#9.75:|Feeling#2.25:|Health#-0.5:|Likability#1.125:|Graph#custom:|\(extra)".utf8))
        return try XCTUnwrap(PetLegacyInventoryPreview(document:document).records.first?.item)
    }
    func testCodableRoundTripPreservesAllParametersButNotQuantity() throws {
        let item=try sample(),metadata=try PetInventoryMetadata(legacy:item)
        let bytes=try JSONEncoder().encode(metadata)
        XCTAssertEqual(try JSONDecoder().decode(PetInventoryMetadata.self,from:bytes),metadata)
        let dictionary=try XCTUnwrap(JSONSerialization.jsonObject(with:bytes) as? [String:Any])
        XCTAssertNil(dictionary["count"]);XCTAssertNil(dictionary["Count"])
        XCTAssertEqual(metadata.name,item.name);XCTAssertEqual(metadata.itemType,item.itemType)
        XCTAssertEqual(metadata.price,-2.5);XCTAssertEqual(metadata.image,"../outside.png")
        XCTAssertEqual(metadata.description,"描述");XCTAssertEqual(metadata.data,"私有/n")
        XCTAssertTrue(metadata.star);XCTAssertTrue(metadata.isSingle);XCTAssertFalse(metadata.canUse);XCTAssertFalse(metadata.visibility)
        XCTAssertEqual(metadata.food?.category,"Drink");XCTAssertEqual(metadata.food?.experience,7)
        XCTAssertEqual(metadata.food?.strength,-1.25);XCTAssertEqual(metadata.food?.food,3.5)
        XCTAssertEqual(metadata.food?.drink,9.75);XCTAssertEqual(metadata.food?.feeling,2.25)
        XCTAssertEqual(metadata.food?.health,-0.5);XCTAssertEqual(metadata.food?.affection,1.125);XCTAssertEqual(metadata.food?.graph,"custom")
    }
    func testFutureMetadataAndInvalidPayloadAreRejectedByValidation() throws {
        let encoded=try JSONEncoder().encode(PetInventoryMetadata(legacy:sample()))
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any]);object["version"]=2
        let future=try JSONDecoder().decode(PetInventoryMetadata.self,from:JSONSerialization.data(withJSONObject:object))
        XCTAssertThrowsError(try future.validate()) { XCTAssertEqual($0 as? PetInventoryMetadata.ValidationError,.unsupportedVersion(2)) }
        var invalid=try PetInventoryMetadata(legacy:sample());invalid.price = .infinity
        XCTAssertThrowsError(try invalid.validate());invalid.price=0;invalid.name=""
        XCTAssertThrowsError(try invalid.validate())
    }
    func testUnknownItemTypeRemainsOpaqueMetadata() throws {
        let metadata=try PetInventoryMetadata(legacy:sample(type:"Plugin"))
        XCTAssertEqual(metadata.itemType,"Plugin");XCTAssertNil(metadata.food)
        XCTAssertEqual(try JSONDecoder().decode(PetInventoryMetadata.self,from:JSONEncoder().encode(metadata)),metadata)
    }
    func testNativeBoundsRejectInsteadOfTruncating() throws {
        var metadata=try PetInventoryMetadata(legacy:sample());metadata.name=String(repeating:"字",count:301)
        XCTAssertThrowsError(try metadata.validate());XCTAssertEqual(metadata.name.count,301)
        metadata.name="x";metadata.data=String(repeating:"x",count:8*1024*1024)
        XCTAssertThrowsError(try metadata.validate())
    }
    func testFoodTypeRequiresFoodPayloadAndKnownCategory() throws {
        let encoded=try JSONEncoder().encode(PetInventoryMetadata(legacy:sample()))
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any]);object.removeValue(forKey:"food")
        let missing=try JSONDecoder().decode(PetInventoryMetadata.self,from:JSONSerialization.data(withJSONObject:object))
        XCTAssertThrowsError(try missing.validate())
        var food=try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any]);var payload=try XCTUnwrap(food["food"] as? [String:Any]);payload["category"]="Future";food["food"]=payload
        let unknown=try JSONDecoder().decode(PetInventoryMetadata.self,from:JSONSerialization.data(withJSONObject:food))
        XCTAssertThrowsError(try unknown.validate())
    }
}
