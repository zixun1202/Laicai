import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var defaultCurrency: String
    var onboardingCompleted: Bool

    init(id: UUID = UUID(), defaultCurrency: String = "CNY", onboardingCompleted: Bool = false) {
        self.id = id
        self.defaultCurrency = defaultCurrency
        self.onboardingCompleted = onboardingCompleted
    }
}
