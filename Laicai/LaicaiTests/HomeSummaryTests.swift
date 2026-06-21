import XCTest
@testable import Laicai

final class HomeSummaryTests: XCTestCase {
    func testWealthSummaryUsesNetWorthCalculatorOutput() {
        let summary = NetWorthCalculator.calculate(assetValues: [200_000, 50_000], liabilityValues: [80_000])
        XCTAssertEqual(summary.netWorth, 170_000)
    }

    func testPortfolioSummarySeparatesAssetsAndLiabilitiesByCategory() {
        let assets = [
            Asset(name: "活期", categoryName: "现金与账户", subtypeName: "银行卡", currentValue: 20_000),
            Asset(name: "指数基金", categoryName: "投资资产", subtypeName: "基金", currentValue: 35_000),
            Asset(name: "房贷", categoryName: "负债", subtypeName: "房贷", currentValue: 500_000)
        ]

        let summary = PortfolioSummaryService.netWorthSummary(for: assets)

        XCTAssertEqual(summary.totalAssets, 55_000)
        XCTAssertEqual(summary.totalLiabilities, 500_000)
        XCTAssertEqual(summary.netWorth, -445_000)
    }

    func testInvestmentSummaryAggregatesOnlyInvestmentAssets() {
        let assets = [
            Asset(name: "货基A", categoryName: "投资资产", subtypeName: "基金", currentValue: 12_000),
            Asset(name: "货基B", categoryName: "投资资产", subtypeName: "基金", currentValue: 8_000),
            Asset(name: "茅台", categoryName: "投资资产", subtypeName: "股票", currentValue: 30_000),
            Asset(name: "工资卡", categoryName: "现金与账户", subtypeName: "银行卡", currentValue: 5_000)
        ]

        let summary = PortfolioSummaryService.investmentSummary(for: assets)

        XCTAssertEqual(summary.totalValue, 50_000)
        XCTAssertEqual(summary.holdingsCount, 3)
        XCTAssertEqual(summary.breakdowns.count, 2)
        XCTAssertEqual(summary.breakdowns.first?.name, "股票")
        XCTAssertEqual(summary.breakdowns.first?.value, 30_000)
        XCTAssertEqual(summary.breakdowns.last?.name, "基金")
        XCTAssertEqual(summary.breakdowns.last?.value, 20_000)
    }
}
