import Foundation

enum PreviewSeed {
    static let sampleTransactions = [
        TransactionRecord(type: .expense, amount: 38, date: .now, categoryName: "餐饮", note: "午饭"),
        TransactionRecord(type: .investmentBuy, amount: 1000, date: .now, categoryName: "基金", note: "买基金")
    ]
}
