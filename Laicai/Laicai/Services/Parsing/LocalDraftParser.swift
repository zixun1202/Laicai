import Foundation

struct ParsedDraft {
    let amount: Decimal
    let suggestedType: TransactionType
    let note: String
}

enum LocalDraftParser {
    static func parse(text: String) -> ParsedDraft? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amountString = extractLastNumberString(in: normalized),
              let amount = Decimal(string: amountString) else {
            return nil
        }

        let suggestedType = inferTransactionType(from: normalized)
        let note = sanitizeNote(in: normalized, matchedAmountText: extractMatchedAmountText(in: normalized) ?? amountString, amountString: amountString)

        return ParsedDraft(amount: amount, suggestedType: suggestedType, note: note)
    }

    private static func inferTransactionType(from text: String) -> TransactionType {
        if containsAnyKeyword(in: text, keywords: ["收入", "工资", "到账", "报销", "收款"]) {
            return .income
        }

        if containsAnyKeyword(in: text, keywords: ["还款", "还房贷", "还车贷"]) {
            return .liabilityRepayment
        }

        if containsAnyKeyword(in: text, keywords: ["卖出", "赎回"]) {
            return .investmentSell
        }

        if containsAnyKeyword(in: text, keywords: ["买基金", "买入", "买股票", "定投", "申购"]) {
            return .investmentBuy
        }

        return .expense
    }

    private static func containsAnyKeyword(in text: String, keywords: [String]) -> Bool {
        keywords.contains(where: text.contains)
    }

    private static func extractLastNumberString(in text: String) -> String? {
        guard let matchedAmountText = extractMatchedAmountText(in: text) else {
            return nil
        }

        return matchedAmountText
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractMatchedAmountText(in text: String) -> String? {
        let pattern = #"[¥￥]?\s*\d[\d,]*(\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard let last = matches.last,
              let range = Range(last.range, in: text) else {
            return nil
        }

        return String(text[range])
    }

    private static func sanitizeNote(in text: String, matchedAmountText: String, amountString: String) -> String {
        var note = text
            .replacingOccurrences(of: matchedAmountText, with: "")
            .replacingOccurrences(of: amountString, with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let whitespaceRegex = try? NSRegularExpression(pattern: #"\s+"#) {
            let range = NSRange(note.startIndex..., in: note)
            note = whitespaceRegex.stringByReplacingMatches(in: note, range: range, withTemplate: " ")
        }

        return note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
