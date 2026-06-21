import XCTest

final class PermissionsAndEmptyStateUITests: XCTestCase {
    func testHomeShowsRecentActivitySectionInEmptyState() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["最近活动"].waitForExistence(timeout: 2))
    }
}
