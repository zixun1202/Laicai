import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    case transfer
    case investmentBuy
    case investmentSell
    case assetValueAdjustment
    case liabilityCreate
    case liabilityRepayment

    var displayName: String {
        switch self {
        case .income:
            return "收入"
        case .expense:
            return "支出"
        case .transfer:
            return "转账"
        case .investmentBuy:
            return "买入投资"
        case .investmentSell:
            return "卖出投资"
        case .assetValueAdjustment:
            return "资产调增"
        case .liabilityCreate:
            return "新增负债"
        case .liabilityRepayment:
            return "负债还款"
        }
    }
}

@Model
final class TransactionRecord {
    var id: UUID
    var typeRawValue: String
    var amount: Double
    var date: Date
    var categoryName: String
    var note: String

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        type: TransactionType,
        amount: Double,
        date: Date,
        categoryName: String,
        note: String = ""
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.amount = amount
        self.date = date
        self.categoryName = categoryName
        self.note = note
    }
}
