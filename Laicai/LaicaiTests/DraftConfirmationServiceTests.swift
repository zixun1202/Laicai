import XCTest
@testable import Laicai

final class DraftConfirmationServiceTests: XCTestCase {
    func testConfirmUsesEditedValuesInsteadOfOriginalDraftValues() {
        let draft = DraftEntry(
            sourceType: "voice",
            originalText: "买基金 1000",
            suggestedType: .investmentBuy,
            amount: 1000,
            note: "买基金"
        )

        let record = DraftConfirmationService.confirm(
            draft,
            type: .expense,
            amount: 888.5,
            categoryName: "生活消费",
            note: "改成晚饭",
            currencyCode: "EUR"
        )

        XCTAssertEqual(record.type, .expense)
        XCTAssertEqual(record.amount, 888.5)
        XCTAssertEqual(record.categoryName, "生活消费")
        XCTAssertEqual(record.note, "改成晚饭")
        XCTAssertEqual(record.currencyCode, "EUR")
    }

    func testTransactionTypeUsesChineseDisplayName() {
        XCTAssertEqual(TransactionType.income.displayName, "收入")
        XCTAssertEqual(TransactionType.expense.displayName, "支出")
        XCTAssertEqual(TransactionType.investmentBuy.displayName, "买入投资")
    }
}
