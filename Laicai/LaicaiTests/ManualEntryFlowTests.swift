import XCTest
@testable import Laicai

final class ManualEntryFlowTests: XCTestCase {
    func testExpenseEntryCreatesTransactionRecord() {
        let record = TransactionRecord(
            type: .expense,
            amount: 38,
            date: .now,
            categoryName: "餐饮",
            note: "午饭"
        )

        XCTAssertEqual(record.typeRawValue, TransactionType.expense.rawValue)
        XCTAssertEqual(record.amount, 38)
        XCTAssertEqual(record.note, "午饭")
    }
}
