import XCTest
@testable import Laicai

final class NetWorthCalculatorTests: XCTestCase {
    func testNetWorthEqualsAssetsMinusLiabilities() {
        let summary = NetWorthCalculator.calculate(
            assetValues: [100_000, 25_000],
            liabilityValues: [30_000]
        )

        XCTAssertEqual(summary.totalAssets, 125_000)
        XCTAssertEqual(summary.totalLiabilities, 30_000)
        XCTAssertEqual(summary.netWorth, 95_000)
    }
}
