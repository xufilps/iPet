import XCTest
@testable import PetCore

final class PetLegacyInventoryPreviewTests: XCTestCase {
    private func preview(_ text:String) throws -> PetLegacyInventoryPreview {
        PetLegacyInventoryPreview(document:try PetLegacyLPSDocument.parse(Data(text.utf8)))
    }
    func testActualLibraryItemAndFoodRoundTrips() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let json=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Tests/Fixtures/legacy-item-fields.json"))) as? [String:Any])
        for c in try XCTUnwrap(json["cases"] as? [[String:Any]]) {
            let p=try preview(try XCTUnwrap(c["input"] as? String))
            let item=try XCTUnwrap(p.records.first?.item),expected=try XCTUnwrap(c["loaded"] as? [String:Any])
            XCTAssertEqual(item.name,expected["Name"] as? String);XCTAssertEqual(item.itemType,expected["ItemType"] as? String)
            XCTAssertEqual(item.price,expected["Price"] as? Double);XCTAssertEqual(item.count,expected["Count"] as? Int)
            XCTAssertEqual(item.image,expected["Image"] as? String);XCTAssertEqual(item.data,expected["Data"] as? String)
            XCTAssertEqual(item.description,expected["Desc"] as? String)
            XCTAssertEqual(item.canUse,expected["CanUse"] as? Bool);XCTAssertEqual(item.star,expected["Star"] as? Bool)
            XCTAssertEqual(item.isSingle,expected["IsSingle"] as? Bool);XCTAssertEqual(item.visibility,expected["Visibility"] as? Bool)
            if let food=item.food {
                XCTAssertEqual(food.category,"Drink");XCTAssertEqual(food.experience,7);XCTAssertNil(food.graph)
                for (key,value) in [("Strength",food.strength),("StrengthFood",food.food),("StrengthDrink",food.drink),("Feeling",food.feeling),("Health",food.health),("Likability",food.affection)] {
                    XCTAssertEqual(value,expected[key] as? Double,key)
                }
            }
            XCTAssertFalse(p.issues.contains { $0.severity == .blocking })
        }
    }
    func testDefaultsCaseAndNumericEnum() throws {
        let p=try preview("itemX:|name#x:|itemtype#Food:|price#2.5:|count#2:|type#4:|star#True:|")
        let item=try XCTUnwrap(p.records.first?.item)
        XCTAssertEqual(item.price,2.5);XCTAssertEqual(item.count,2);XCTAssertTrue(item.star)
        XCTAssertEqual(item.food?.category,"Drink");XCTAssertEqual(item.food?.experience,0)
        XCTAssertTrue(item.canUse);XCTAssertTrue(item.visibility);XCTAssertNil(item.image)
        XCTAssertTrue(p.issues.contains { $0.path=="itemX.Graph" })
    }
    func testInvalidDuplicateAndUnknownFieldsPreserveRawRecord() throws {
        for bad in ["Count#2147483648", "Price#NaN", "Count#01", "Type#drink", "Type#99", "CanUse#0", "Price#1,5", "Count#2:|count#3"] {
            let p=try preview("item0:|name#x:|itemtype#Food:|"+bad+":|")
            XCTAssertNil(p.records[0].item,bad);XCTAssertTrue(p.issues.contains { $0.severity == .blocking },bad)
            XCTAssertFalse(p.records[0].sourceLine.fields.isEmpty)
        }
        let unknown=try preview("item0:|name#x:|itemtype#Food:|plugin#raw:|")
        XCTAssertNotNil(unknown.records[0].item)
        XCTAssertTrue(unknown.issues.contains { $0.path=="item0.plugin" && $0.severity == .blocking })
    }
    func testUnknownTypeAndNamesAreNotReplacedFromCatalog() throws {
        let p=try preview("itemCustom:|name#蛋糕:|itemtype#Plugin:|Price#900:|Count#-3:|Data#custom:|\nitem1:|Name#wrong:|")
        XCTAssertEqual(p.records.count,2);XCTAssertEqual(p.records[0].item?.itemType,"Plugin")
        XCTAssertEqual(p.records[0].item?.price,900);XCTAssertEqual(p.records[0].item?.count,-3)
        XCTAssertTrue(p.issues.contains { $0.path=="itemCustom.itemtype" && $0.severity == .blocking })
        XCTAssertNil(p.records[1].item)
    }
    func testNameOnlyMergeReportsParameterConflictsAndPreservesBoth() throws {
        let p=try preview("item0:|name#same:|Price#1:|Count#2:|\nitem1:|name#same:|Price#9:|Count#3:|IsSingle#True:|")
        XCTAssertEqual(p.records.count,2);XCTAssertEqual(p.merges.count,1)
        XCTAssertEqual(p.merges[0].recordIndices,[0,1]);XCTAssertEqual(p.merges[0].totalCount,5)
        XCTAssertTrue(p.merges[0].hasParameterConflict);XCTAssertEqual(p.records[1].item?.price,9)
    }
    func testOrdinalNamesAndIdenticalMerge() throws {
        let p=try preview("item0:|name#é:|Count#2:|\nitem1:|name#e\u{301}:|Count#3:|\nitem2:|name#é:|Count#4:|")
        XCTAssertEqual(p.merges.count,1);XCTAssertEqual(p.merges[0].recordIndices,[0,2])
        XCTAssertEqual(p.merges[0].totalCount,6);XCTAssertFalse(p.merges[0].hasParameterConflict)
    }
    func testNullLiteralAndDiagnosticBounds() throws {
        XCTAssertNil(try preview("item0:|name#x:|Image#/null:|").records[0].item?.image)
        XCTAssertEqual(try preview("item0:|name#x:|Image#/!null:|").records[0].item?.image,"/null")
        let p=try preview((0..<40).map {"item\($0):|name#x\($0):|unknown#x:|"}.joined(separator:"\n"))
        XCTAssertEqual(p.records.count,40);XCTAssertEqual(p.issues.count,200);XCTAssertGreaterThan(p.omittedIssueCount,0)
    }
    func testUnknownParametersAndDuplicateRowsRemainAmbiguous() throws {
        let p=try preview("item0:|name#same:|plugin#first:|\nitem1:|name#same:|plugin#second:|")
        XCTAssertTrue(p.merges[0].hasParameterConflict)
        let repeated=try preview("item0:|name#a:|\nitem0:|name#b:|")
        XCTAssertEqual(repeated.records.count,2)
        XCTAssertTrue(repeated.issues.contains { $0.path=="item0" && $0.severity == .blocking })
    }
    func testMergedCountOverflowIsReportedWithoutWrapping() throws {
        let p=try preview("item0:|name#same:|Count#2147483647:|\nitem1:|name#same:|Count#1:|")
        XCTAssertEqual(p.merges[0].totalCount,2147483648)
        XCTAssertTrue(p.issues.contains { $0.path=="inventory.same" && $0.severity == .blocking })
    }
    func testSavedFoodStarAndDataAreRetainedOnInventoryLoadPath() throws {
        let p=try preview("item0:|name#x:|itemtype#Food:|Star#True:|Data#saved:|")
        XCTAssertEqual(p.records[0].item?.data,"saved");XCTAssertEqual(p.records[0].item?.star,true)
        XCTAssertFalse(p.issues.contains { $0.message.contains("重建") })
    }
    func testSavePreviewIncludesInventoryWithoutClaimingImportReady() throws {
        let data=Data("vpet:|name#x:|\nitem0:|name#custom:|Count#2:|".utf8)
        let p=try PetLegacySavePreview(data:data)
        XCTAssertEqual(p.inventory.records.first?.item?.count,2);XCTAssertEqual(p.sourceData,data)
        XCTAssertTrue(p.issues.contains { $0.path=="item0" && $0.severity == .blocking })
    }
}
