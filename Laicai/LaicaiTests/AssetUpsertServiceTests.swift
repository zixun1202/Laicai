import XCTest
@testable import Laicai

final class AssetUpsertServiceTests: XCTestCase {
    func testCreateBuildsNewAssetFromForm() {
        let form = AssetFormData(
            name: "招商银行卡",
            categoryName: "现金与账户",
            subtypeName: "银行卡",
            currentValue: 5000,
            costBasis: 5000,
            linkedAccountName: "工资卡"
        )

        let asset = AssetUpsertService.apply(form: form, to: nil)

        XCTAssertEqual(asset.name, "招商银行卡")
        XCTAssertEqual(asset.categoryName, "现金与账户")
        XCTAssertEqual(asset.subtypeName, "银行卡")
        XCTAssertEqual(asset.currentValue, 5000)
        XCTAssertEqual(asset.costBasis, 5000)
        XCTAssertEqual(asset.linkedAccountName, "工资卡")
    }

    func testApplyUpdatesExistingAsset() {
        let asset = Asset(
            name: "旧基金",
            categoryName: "投资资产",
            subtypeName: "基金",
            currentValue: 1200,
            costBasis: 1000,
            linkedAccountName: "天天基金"
        )
        let form = AssetFormData(
            name: "新基金",
            categoryName: "投资资产",
            subtypeName: "基金",
            currentValue: 2200,
            costBasis: 1800,
            linkedAccountName: "蚂蚁财富"
        )

        let updated = AssetUpsertService.apply(form: form, to: asset)

        XCTAssertTrue(updated === asset)
        XCTAssertEqual(updated.name, "新基金")
        XCTAssertEqual(updated.currentValue, 2200)
        XCTAssertEqual(updated.costBasis, 1800)
        XCTAssertEqual(updated.linkedAccountName, "蚂蚁财富")
    }
}
