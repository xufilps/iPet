import XCTest
import PetCore
@testable import PetRendering

final class PetRaisePlacementTests: XCTestCase {
    var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/PetAssets") }
    func testOriginalAnchorsAtMultipleScalesAndNegativeScreenCoordinates() throws {
        let manifest = try PetManifest.load(from: root)
        for (mood, point) in [(PetMood.normal, CGPoint(x:290,y:128)), (.ill, CGPoint(x:225,y:115))] {
            let anchor = try XCTUnwrap(manifest.raiseAnchors?[mood.rawValue])
            XCTAssertEqual(anchor.x, point.x); XCTAssertEqual(anchor.y, point.y)
            for size in [250.0,500,1000] {
                let result = try XCTUnwrap(PetRaisePlacement.origin(cursor:CGPoint(x:-600,y:400), frame:CGRect(x:0,y:0,width:size,height:size), canvas:CGSize(width:500,height:500), anchor:anchor))
                XCTAssertEqual(result.x, -600-point.x*size/500, accuracy:0.00001)
                XCTAssertEqual(result.y, 400-(500-point.y)*size/500, accuracy:0.00001)
            }
        }
    }
    func testAxisDeadZoneUsesLogicalUnitsAndAspectFitPadding() throws {
        let anchor = RaiseAnchor(x:290,y:128)
        let frame = CGRect(x:-100,y:50,width:250,height:300)
        // Aspect fit: 25pt vertical padding, anchor at (145, 211) in the window.
        let still = try XCTUnwrap(PetRaisePlacement.origin(cursor:CGPoint(x:45.49,y:261.49),frame:frame,canvas:CGSize(width:500,height:500),anchor:anchor))
        XCTAssertEqual(still,frame.origin)
        let moved = try XCTUnwrap(PetRaisePlacement.origin(cursor:CGPoint(x:45.5,y:262),frame:frame,canvas:CGSize(width:500,height:500),anchor:anchor))
        XCTAssertEqual(moved,CGPoint(x:-99.5,y:51))
        XCTAssertNil(PetRaisePlacement.origin(cursor:CGPoint(x:Double.nan,y:0),frame:frame,canvas:CGSize(width:500,height:500),anchor:anchor))
    }
    func testLegacyManifestAndInvalidAnchorValidation() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("manifest.json"))) as? [String:Any])
        object.removeValue(forKey:"raiseAnchors")
        let legacy = try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:object))
        XCTAssertNil(legacy.raiseAnchors)
        try legacy.validate(root:root,checkFiles:false)
        object["raiseAnchors"] = ["Nomal":["x":501,"y":128]]
        let invalid = try JSONDecoder().decode(PetManifest.self,from:JSONSerialization.data(withJSONObject:object))
        XCTAssertThrowsError(try invalid.validate(root:root,checkFiles:false))
    }
}
