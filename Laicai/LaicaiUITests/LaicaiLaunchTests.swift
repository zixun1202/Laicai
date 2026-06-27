import XCTest

final class LaicaiLaunchTests: XCTestCase {
    func testAppLaunchesToHome() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Laicai Daily"].waitForExistence(timeout: 2))
    }
}
