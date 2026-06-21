import XCTest

final class LaicaiLaunchTests: XCTestCase {
    func testAppLaunchesToHome() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["财富总览"].waitForExistence(timeout: 2))
    }
}
