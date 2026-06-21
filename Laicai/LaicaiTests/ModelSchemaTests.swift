import XCTest
@testable import Laicai

final class ModelSchemaTests: XCTestCase {
    func testDefaultCategoriesIncludeFourTopLevelGroups() {
        let categories = DefaultCategorySeeder.defaultCategories()
        XCTAssertEqual(categories.map(\.name), ["现金与账户", "投资资产", "固定资产", "负债"])
    }
}
