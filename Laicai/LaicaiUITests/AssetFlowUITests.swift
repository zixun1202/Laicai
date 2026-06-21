import XCTest

final class AssetFlowUITests: XCTestCase {
    func testAssetsTabShowsTopLevelCategories() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["资产"].tap()

        XCTAssertTrue(app.staticTexts["现金与账户"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["投资资产"].exists)
        XCTAssertTrue(app.staticTexts["固定资产"].exists)
        XCTAssertTrue(app.staticTexts["负债"].exists)
    }

    func testCanCreateAssetFromAssetsTab() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["资产"].tap()
        app.navigationBars["资产"].buttons["新增资产"].tap()

        let nameField = app.textFields["资产名称"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("测试基金")

        let currentValueField = app.textFields["当前价值"]
        currentValueField.tap()
        currentValueField.typeText("1234")

        app.navigationBars["新增资产"].buttons["保存"].tap()

        XCTAssertTrue(app.staticTexts["测试基金"].waitForExistence(timeout: 2))
    }
}
