import Foundation

struct NetWorthSummary: Equatable {
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let netWorth: Decimal
}

enum NetWorthCalculator {
    static func calculate(assetValues: [Decimal], liabilityValues: [Decimal]) -> NetWorthSummary {
        let totalAssets = assetValues.reduce(0, +)
        let totalLiabilities = liabilityValues.reduce(0, +)
        return NetWorthSummary(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netWorth: totalAssets - totalLiabilities
        )
    }
}
