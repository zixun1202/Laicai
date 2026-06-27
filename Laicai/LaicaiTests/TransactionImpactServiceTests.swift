import XCTest
@testable import Laicai

final class TransactionImpactServiceTests: XCTestCase {
    func testExpenseReducesSelectedAssetValue() {
        let asset = Asset(
            name: "工资卡",
            categoryName: "现金与账户",
            subtypeName: "银行卡",
            currentValue: 1_000
        )
        let record = TransactionRecord(
            type: .expense,
            amount: 38,
            date: .now,
            categoryName: "餐饮",
            note: "午饭"
        )

        TransactionImpactService.apply(record, to: asset)

        XCTAssertEqual(asset.currentValue, 962)
        XCTAssertEqual(record.linkedAssetID, asset.id)
        XCTAssertEqual(record.assetCurrentValueDelta, -38)
        XCTAssertEqual(record.assetCostBasisDelta, 0)
    }

    func testInvestmentBuyIncreasesValueAndCostBasis() {
        let asset = Asset(
            name: "沪深300",
            categoryName: "投资资产",
            subtypeName: "基金",
            currentValue: 2_000,
            costBasis: 1_800
        )
        let record = TransactionRecord(
            type: .investmentBuy,
            amount: 500,
            date: .now,
            categoryName: "基金买入",
            note: "定投"
        )

        TransactionImpactService.apply(record, to: asset)

        XCTAssertEqual(asset.currentValue, 2_500)
        XCTAssertEqual(asset.costBasis, 2_300)
        XCTAssertEqual(record.assetCurrentValueDelta, 500)
        XCTAssertEqual(record.assetCostBasisDelta, 500)
    }

    func testLiabilityRepaymentDoesNotGoBelowZero() {
        let liability = Asset(
            name: "消费贷",
            categoryName: "负债",
            subtypeName: "消费贷",
            currentValue: 300
        )
        let record = TransactionRecord(
            type: .liabilityRepayment,
            amount: 500,
            date: .now,
            categoryName: "消费贷还款",
            note: "结清"
        )

        TransactionImpactService.apply(record, to: liability)

        XCTAssertEqual(liability.currentValue, 0)
        XCTAssertEqual(record.assetCurrentValueDelta, -300)
    }

    func testReverseUsesRecordedDeltaForCappedLiabilityRepayment() {
        let liability = Asset(
            name: "消费贷",
            categoryName: "负债",
            subtypeName: "消费贷",
            currentValue: 300
        )
        let record = TransactionRecord(
            type: .liabilityRepayment,
            amount: 500,
            date: .now,
            categoryName: "消费贷还款",
            note: "结清"
        )

        TransactionImpactService.apply(record, to: liability)
        TransactionImpactService.reverse(record, from: liability)

        XCTAssertEqual(liability.currentValue, 300)
    }

    func testReverseRestoresInvestmentCostBasisFromRecordedDelta() {
        let asset = Asset(
            name: "沪深300",
            categoryName: "投资资产",
            subtypeName: "基金",
            currentValue: 200,
            costBasis: 120
        )
        let record = TransactionRecord(
            type: .investmentSell,
            amount: 300,
            date: .now,
            categoryName: "基金卖出",
            note: "清仓"
        )

        TransactionImpactService.apply(record, to: asset)
        TransactionImpactService.reverse(record, from: asset)

        XCTAssertEqual(asset.currentValue, 200)
        XCTAssertEqual(asset.costBasis, 120)
    }

    func testExpenseCannotReduceLiabilityByAccident() {
        let liability = Asset(
            name: "消费贷",
            categoryName: "负债",
            subtypeName: "消费贷",
            currentValue: 1_000
        )
        let record = TransactionRecord(
            type: .expense,
            amount: 200,
            date: .now,
            categoryName: "购物",
            note: "外套"
        )

        let applied = TransactionImpactService.apply(record, to: liability)

        XCTAssertFalse(applied)
        XCTAssertEqual(liability.currentValue, 1_000)
        XCTAssertNil(record.linkedAssetID)
        XCTAssertEqual(record.assetCurrentValueDelta, 0)
    }

    func testApplicableAssetsMatchTransactionType() {
        let cash = Asset(name: "工资卡", categoryName: "现金与账户", subtypeName: "银行卡")
        let fund = Asset(name: "指数基金", categoryName: "投资资产", subtypeName: "基金")
        let loan = Asset(name: "消费贷", categoryName: "负债", subtypeName: "消费贷")

        XCTAssertEqual(
            TransactionImpactService.applicableAssets(for: .expense, in: [cash, fund, loan]).map(\.name),
            ["工资卡"]
        )
        XCTAssertEqual(
            TransactionImpactService.applicableAssets(for: .investmentBuy, in: [cash, fund, loan]).map(\.name),
            ["指数基金"]
        )
        XCTAssertEqual(
            TransactionImpactService.applicableAssets(for: .liabilityRepayment, in: [cash, fund, loan]).map(\.name),
            ["消费贷"]
        )
        XCTAssertEqual(
            TransactionImpactService.applicableAssets(for: .income, in: [cash, fund, loan]).map(\.name),
            ["工资卡"]
        )
        XCTAssertEqual(
            TransactionImpactService.applicableAssets(for: .investmentSell, in: [cash, fund, loan]).map(\.name),
            ["指数基金"]
        )
        XCTAssertEqual(
            TransactionImpactService.applicableAssets(for: .liabilityCreate, in: [cash, fund, loan]).map(\.name),
            ["消费贷"]
        )
        XCTAssertEqual(
            TransactionImpactService.applicableAssets(for: .transfer, in: [cash, fund, loan]).map(\.name),
            []
        )
        XCTAssertEqual(
            TransactionImpactService.applicableAssets(for: .assetValueAdjustment, in: [cash, fund, loan]).map(\.name),
            ["工资卡", "指数基金"]
        )
    }
}
