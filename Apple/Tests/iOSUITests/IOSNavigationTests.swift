// SPDX-License-Identifier: Apache-2.0
import XCTest
import UIKit

@MainActor final class IOSNavigationTests:XCTestCase {
    private var app:XCUIApplication!
    override func setUp() async throws {
        continueAfterFailure=false
        XCUIDevice.shared.orientation = .portrait
        app=XCUIApplication()
        app.launchEnvironment["IPET_TEST_HOST"]="1"
        app.launch()
        XCTAssertTrue(app.buttons["更多"].waitForExistence(timeout:20))
    }
    override func tearDown() async throws {
        app?.terminate();XCUIDevice.shared.orientation = .portrait
    }
    private func reachable(_ label:String) -> XCUIElement {
        let button=app.buttons[label].firstMatch
        _ = button.waitForExistence(timeout:2)
        // iPad's adaptive tabs may not expose a TabBar accessibility element.
        // Navigation controls and sheet dismissal buttons are outside the Form.
        let checkBounds=["预览消息","关闭"].contains(label)
        let top=checkBounds && app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY:app.frame.minY
        let bottom=checkBounds && app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY:app.frame.maxY
        func visible() -> Bool {
            button.exists && button.isHittable && (!checkBounds || (button.frame.midY>top && button.frame.midY<bottom))
        }
        for _ in 0..<8 {
            // SwiftUI can report a row behind the navigation bar as hittable after
            // rotation. Require its center to be inside the visible Form as well.
            if visible() { break }
            let upward = !button.exists || button.frame.midY>(top+bottom)/2
            let distance=button.exists ? min(120,max(30,abs(button.frame.midY-(top+bottom)/2)*0.7)):120
            // A whole-screen swipe can land on a Slider, which consumes the drag.
            // Start on its text label to exercise the Form's actual scrolling instead.
            if let label=["字号","透明度","逐字间隔","停留时间倍率"].map({ app.staticTexts[$0] }).last(where:{ $0.exists && $0.isHittable && $0.frame.midY>top && $0.frame.midY<bottom }) {
                let start=label.coordinate(withNormalizedOffset:CGVector(dx:0.1,dy:0.5))
                start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:0,dy:(upward ? -1:1)*distance)),withVelocity:.slow,thenHoldForDuration:0.2)
            } else {
                let scroll=app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch:app.collectionViews.firstMatch
                XCTAssertTrue(scroll.exists,"Missing scroll container")
                let start=scroll.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:upward ? 0.7:0.3))
                let end=start.withOffset(CGVector(dx:0,dy:(upward ? -1:1)*distance))
                start.press(forDuration:0.05,thenDragTo:end,withVelocity:.slow,thenHoldForDuration:0.2)
            }
        }
        XCTAssertTrue(button.exists,"Missing button: \(label)")
        if !visible() { capture("unreachable-"+label) }
        XCTAssertTrue(visible(),"Unreachable or obscured button: \(label), frame=\(button.frame), visibleY=\(top)...\(bottom)")
        return button
    }
    private func tap(_ label:String) { reachable(label).tap() }
    private func capture(_ name:String) {
        let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func testCareActivityAndForegroundReturn() {
        tap("更多");tap("休息")
        XCTAssertTrue(app.buttons["起床"].waitForExistence(timeout:5))
        tap("起床");tap("摸头");tap("投喂");tap("饮水")
        tap("活动");tap("开始文案")
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout:5))
        tap("暂停");tap("继续");tap("停止")
        XCTAssertTrue(app.buttons["开始文案"].waitForExistence(timeout:5))
        let barbecue=app.buttons["开始烧烤"]
        XCTAssertTrue(barbecue.exists);XCTAssertFalse(barbecue.isEnabled)
        XCUIDevice.shared.press(.home);app.activate()
        XCTAssertTrue(app.buttons["开始文案"].waitForExistence(timeout:8))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout:8))
        tap("设置");XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout:8))
        capture("settings-landscape")
    }
    func testShopInventoryAndMessagePreview() {
        tap("商店")
        let milk=app.buttons.containing(.staticText,identifier:"ab钙奶").firstMatch
        XCTAssertTrue(milk.waitForExistence(timeout:8));milk.tap()
        tap("购买放入背包");tap("完成");tap("背包")
        let owned=app.buttons.containing(.staticText,identifier:"ab钙奶").firstMatch
        XCTAssertTrue(owned.waitForExistence(timeout:8));owned.tap()
        XCTAssertTrue(app.staticTexts["库存：1"].waitForExistence(timeout:5))
        tap("使用一件")
        XCTAssertTrue(app.staticTexts["库存：0"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["使用一件"].isEnabled)
        tap("完成");tap("设置");tap("预览消息")
        let preview=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","你好，这是消息预览")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout:10))
        capture("settings-preview")
        tap("关闭")
        XCTAssertFalse(preview.exists)
    }
    func testSettingsOrientationLayout() {
        let tablet=UIDevice.current.userInterfaceIdiom == .pad
        tap("设置")
        let orientations:[UIDeviceOrientation] = tablet ? [.landscapeLeft,.portraitUpsideDown,.landscapeRight,.portrait]:[.landscapeLeft,.landscapeRight,.portrait]
        for orientation in orientations {
            XCUIDevice.shared.orientation=orientation
            let horizontal=orientation.isLandscape
            let settled=NSPredicate { object,_ in
                guard let element=object as? XCUIElement else { return false }
                return horizontal ? element.frame.width>element.frame.height:element.frame.height>element.frame.width
            }
            expectation(for:settled,evaluatedWith:app)
            waitForExpectations(timeout:10)
            capture("settled-start-\(orientation.rawValue)")
            tap("预览消息")
            let close=reachable("关闭")
            let text=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","你好，这是消息预览")).firstMatch
            XCTAssertTrue(text.waitForExistence(timeout:8))
            capture("orientation-\(orientation.rawValue)")
            close.tap()
        }
    }

}
