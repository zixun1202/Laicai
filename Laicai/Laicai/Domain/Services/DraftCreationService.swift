import Foundation

enum DraftCreationService {
    static func createDraft(sourceType: String, originalText: String) -> DraftEntry? {
        guard let parsed = LocalDraftParser.parse(text: originalText) else {
            return nil
        }

        return DraftEntry(
            sourceType: sourceType,
            originalText: originalText,
            suggestedType: parsed.suggestedType,
            amount: NSDecimalNumber(decimal: parsed.amount).doubleValue,
            note: parsed.note
        )
    }
}
