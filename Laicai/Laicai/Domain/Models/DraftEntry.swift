import Foundation
import SwiftData

@Model
final class DraftEntry {
    var id: UUID
    var sourceType: String
    var originalText: String
    var suggestedTypeRawValue: String
    var amount: Double
    var note: String
    var createdAt: Date

    var suggestedType: TransactionType {
        get { TransactionType(rawValue: suggestedTypeRawValue) ?? .expense }
        set { suggestedTypeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        sourceType: String,
        originalText: String,
        suggestedType: TransactionType,
        amount: Double,
        note: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sourceType = sourceType
        self.originalText = originalText
        self.suggestedTypeRawValue = suggestedType.rawValue
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
    }
}
