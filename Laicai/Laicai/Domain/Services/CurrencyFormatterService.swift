import Foundation

enum CurrencyFormatterService {
    static let supportedCurrencyCodes = ["CNY", "USD", "EUR", "JPY"]

    static func symbol(for currencyCode: String) -> String {
        switch currencyCode {
        case "USD":
            return "$"
        case "EUR":
            return "€"
        case "JPY":
            return "¥"
        default:
            return "¥"
        }
    }

    static func money(
        _ value: Decimal,
        currencyCode: String,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 2
    ) -> String {
        let number = NSDecimalNumber(decimal: value)
        let isNegative = number.compare(NSDecimalNumber.zero) == .orderedAscending
        let absoluteNumber = isNegative ? number.multiplying(by: -1) : number
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits

        let formattedValue = formatter.string(from: absoluteNumber) ?? absoluteNumber.stringValue
        return "\(isNegative ? "-" : "")\(symbol(for: currencyCode))\(formattedValue)"
    }

    static func money(
        _ value: Double,
        currencyCode: String,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 2
    ) -> String {
        money(
            Decimal(value),
            currencyCode: currencyCode,
            minimumFractionDigits: minimumFractionDigits,
            maximumFractionDigits: maximumFractionDigits
        )
    }
}
