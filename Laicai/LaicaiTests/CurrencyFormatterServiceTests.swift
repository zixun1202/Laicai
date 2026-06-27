import XCTest
@testable import Laicai

final class CurrencyFormatterServiceTests: XCTestCase {
    func testFormatsSupportedCurrencySymbols() {
        XCTAssertEqual(CurrencyFormatterService.money(Decimal(1288.5), currencyCode: "CNY"), "¥1,288.5")
        XCTAssertEqual(CurrencyFormatterService.money(Decimal(1288.5), currencyCode: "USD"), "$1,288.5")
        XCTAssertEqual(CurrencyFormatterService.money(Decimal(1288.5), currencyCode: "EUR"), "€1,288.5")
    }

    func testCanForceTwoFractionDigits() {
        XCTAssertEqual(
            CurrencyFormatterService.money(
                38.0,
                currencyCode: "CNY",
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            ),
            "¥38.00"
        )
    }
}
