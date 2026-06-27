import Foundation

enum DraftConfirmationService {
    static func confirm(_ draft: DraftEntry, categoryName: String) -> TransactionRecord {
        confirm(
            draft,
            type: draft.suggestedType,
            amount: draft.amount,
            categoryName: categoryName,
            note: draft.note
        )
    }

    static func confirm(
        _ draft: DraftEntry,
        type: TransactionType,
        amount: Double,
        categoryName: String,
        note: String,
        currencyCode: String = "CNY"
    ) -> TransactionRecord {
        TransactionRecord(
            type: type,
            amount: amount,
            date: .now,
            categoryName: categoryName,
            note: note,
            currencyCode: currencyCode
        )
    }
}
