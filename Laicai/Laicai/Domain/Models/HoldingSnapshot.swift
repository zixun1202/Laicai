import Foundation
import SwiftData

@Model
final class HoldingSnapshot {
    var id: UUID
    var totalInvestmentValue: Double
    var capturedAt: Date

    init(id: UUID = UUID(), totalInvestmentValue: Double, capturedAt: Date = .now) {
        self.id = id
        self.totalInvestmentValue = totalInvestmentValue
        self.capturedAt = capturedAt
    }
}
