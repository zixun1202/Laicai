import Foundation

struct AssetFormData {
    let name: String
    let categoryName: String
    let subtypeName: String
    let currentValue: Double
    let costBasis: Double
    let linkedAccountName: String
    let currencyCode: String
    let quoteSymbol: String
    let quoteMarket: FundMarketRegion
}

enum AssetUpsertService {
    static func apply(form: AssetFormData, to asset: Asset?) -> Asset {
        let normalizedQuoteSymbol = normalizedQuoteSymbol(
            form.quoteSymbol,
            categoryName: form.categoryName,
            subtypeName: form.subtypeName
        )
        let target = asset ?? Asset(
            name: form.name,
            categoryName: form.categoryName,
            subtypeName: form.subtypeName,
            currentValue: form.currentValue,
            costBasis: form.costBasis,
            linkedAccountName: form.linkedAccountName,
            currencyCode: form.currencyCode,
            quoteSymbol: normalizedQuoteSymbol,
            quoteMarket: form.quoteMarket
        )

        target.name = form.name
        target.categoryName = form.categoryName
        target.subtypeName = form.subtypeName
        target.currentValue = form.currentValue
        target.costBasis = form.costBasis
        target.linkedAccountName = form.linkedAccountName
        target.currencyCode = form.currencyCode
        target.quoteSymbol = normalizedQuoteSymbol
        target.quoteMarketRawValue = normalizedQuoteSymbol == nil ? nil : form.quoteMarket.rawValue

        return target
    }

    static func supportsQuote(categoryName: String, subtypeName: String) -> Bool {
        categoryName == "投资资产" && ["基金", "股票", "ETF", "理财产品"].contains(subtypeName)
    }

    private static func normalizedQuoteSymbol(
        _ symbol: String,
        categoryName: String,
        subtypeName: String
    ) -> String? {
        guard supportsQuote(categoryName: categoryName, subtypeName: subtypeName) else {
            return nil
        }

        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSymbol.isEmpty else {
            return nil
        }
        return trimmedSymbol.uppercased()
    }
}
