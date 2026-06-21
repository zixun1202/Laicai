import XCTest
@testable import Laicai

final class LocalDraftParserTests: XCTestCase {
    func testParserExtractsExpenseAmountFromShortSentence() {
        let draft = LocalDraftParser.parse(text: "午饭 38")
        XCTAssertEqual(draft?.amount, 38)
        XCTAssertEqual(draft?.suggestedType, .expense)
    }

    func testParserRecognizesInvestmentBuyWithCurrencySymbolAndComma() {
        let draft = LocalDraftParser.parse(text: "买基金 ¥1,288.50")

        XCTAssertEqual(draft?.amount, 1288.50)
        XCTAssertEqual(draft?.suggestedType, .investmentBuy)
        XCTAssertEqual(draft?.note, "买基金")
    }

    func testParserRecognizesSalaryAsIncome() {
        let draft = LocalDraftParser.parse(text: "工资到账 12000")

        XCTAssertEqual(draft?.amount, 12000)
        XCTAssertEqual(draft?.suggestedType, .income)
        XCTAssertEqual(draft?.note, "工资到账")
    }
}
