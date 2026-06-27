import Foundation

struct InvestmentBreakdown: Equatable {
    let name: String
    let value: Decimal
}

struct InvestmentSummary: Equatable {
    let totalValue: Decimal
    let holdingsCount: Int
    let breakdowns: [InvestmentBreakdown]
}

enum PortfolioSummaryService {
    private static let liabilityCategoryName = "负债"
    private static let investmentCategoryName = "投资资产"

    static func netWorthSummary(for assets: [Asset]) -> NetWorthSummary {
        let assetValues = assets
            .filter { $0.categoryName != liabilityCategoryName }
            .map { Decimal($0.currentValue) }
        let liabilityValues = assets
            .filter { $0.categoryName == liabilityCategoryName }
            .map { Decimal($0.currentValue) }

        return NetWorthCalculator.calculate(
            assetValues: assetValues,
            liabilityValues: liabilityValues
        )
    }

    static func investmentSummary(for assets: [Asset]) -> InvestmentSummary {
        let investmentAssets = assets.filter { $0.categoryName == investmentCategoryName }
        let groupedValues = Dictionary(grouping: investmentAssets, by: \.subtypeName)
            .mapValues { items in
                items.reduce(Decimal(0)) { total, asset in
                    total + Decimal(asset.currentValue)
                }
            }

        let breakdowns = groupedValues
            .map { InvestmentBreakdown(name: $0.key, value: $0.value) }
            .sorted {
                if $0.value == $1.value {
                    return $0.name < $1.name
                }
                return $0.value > $1.value
            }

        return InvestmentSummary(
            totalValue: investmentAssets.reduce(Decimal(0)) { total, asset in
                total + Decimal(asset.currentValue)
            },
            holdingsCount: investmentAssets.count,
            breakdowns: breakdowns
        )
    }
}
