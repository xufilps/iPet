import XCTest
@testable import PetCore
final class PetCatalogTests: XCTestCase {
    func testRealCatalogueAndInvalidPaths() throws {
        let apple = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try PetCatalog.load(from: apple.appendingPathComponent("Resources/PetAssets/gameplay.json"))
        XCTAssertEqual(catalog.activities.count,13); XCTAssertEqual(catalog.items.count,118)
        XCTAssertEqual(catalog.packageDefinitions.count,14)
        XCTAssertEqual(catalog.activity("core.activity.文案")?.moneyBase,8)
        XCTAssertEqual(catalog.item("core.item.太阳系")?.strength,-100)
        var changed = catalog; changed.items[0].imagePath = "../escape.png"
        XCTAssertThrowsError(try changed.validate())
        changed = catalog; changed.items[0].price = .nan
        XCTAssertThrowsError(try changed.validate())
        changed = catalog; changed.items.append(changed.items[0])
        XCTAssertThrowsError(try changed.validate())
    }
}
