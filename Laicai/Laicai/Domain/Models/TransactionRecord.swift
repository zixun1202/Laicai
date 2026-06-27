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

enum TransactionCategoryCatalog {
    static func categories(for type: TransactionType) -> [String] {
        switch type {
        case .income:
            return ["工资", "报销", "收款", "理财收益", "其他收入"]
        case .expense:
            return ["餐饮", "交通", "购物", "住房", "娱乐", "医疗", "日常支出"]
        case .transfer:
            return ["账户转账", "信用卡还款", "内部转移"]
        case .investmentBuy:
            return ["基金买入", "股票买入", "理财申购", "定投"]
        case .investmentSell:
            return ["基金卖出", "股票卖出", "理财赎回"]
        case .assetValueAdjustment:
            return ["资产调整", "市值更新", "现金校准"]
        case .liabilityCreate:
            return ["房贷", "车贷", "消费贷", "信用卡应还"]
        case .liabilityRepayment:
            return ["房贷还款", "车贷还款", "消费贷还款", "信用卡还款"]
        }
    }

    static func defaultCategory(for type: TransactionType) -> String {
        categories(for: type).first ?? type.displayName
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
    var currencyCode: String?
    var linkedAssetID: UUID?
    var assetCurrentValueDelta: Double
    var assetCostBasisDelta: Double

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
        note: String = "",
        currencyCode: String = "CNY",
        linkedAssetID: UUID? = nil,
        assetCurrentValueDelta: Double = 0,
        assetCostBasisDelta: Double = 0
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.amount = amount
        self.date = date
        self.categoryName = categoryName
        self.note = note
        self.currencyCode = currencyCode
        self.linkedAssetID = linkedAssetID
        self.assetCurrentValueDelta = assetCurrentValueDelta
        self.assetCostBasisDelta = assetCostBasisDelta
    }
}
