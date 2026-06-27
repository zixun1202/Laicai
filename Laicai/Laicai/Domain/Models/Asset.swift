import Foundation
import SwiftData

@Model
final class Asset {
    var id: UUID
    var name: String
    var categoryName: String
    var subtypeName: String
    var currentValue: Double
    var costBasis: Double
    var linkedAccountName: String
    var currencyCode: String?
    var quoteSymbol: String?
    var quoteMarketRawValue: String?
    var holdingUnits: Double?

    var quoteMarket: FundMarketRegion {
        get { FundMarketRegion(rawValue: quoteMarketRawValue ?? "") ?? .china }
        set { quoteMarketRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        categoryName: String,
        subtypeName: String,
        currentValue: Double = 0,
        costBasis: Double = 0,
        linkedAccountName: String = "",
        currencyCode: String = "CNY",
        quoteSymbol: String? = nil,
        quoteMarket: FundMarketRegion = .china,
        holdingUnits: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryName = categoryName
        self.subtypeName = subtypeName
        self.currentValue = currentValue
        self.costBasis = costBasis
        self.linkedAccountName = linkedAccountName
        self.currencyCode = currencyCode
        self.quoteSymbol = quoteSymbol
        self.quoteMarketRawValue = quoteSymbol == nil || quoteSymbol?.isEmpty == true ? nil : quoteMarket.rawValue
        self.holdingUnits = holdingUnits
    }
}
