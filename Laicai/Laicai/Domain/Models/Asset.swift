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

    init(
        id: UUID = UUID(),
        name: String,
        categoryName: String,
        subtypeName: String,
        currentValue: Double = 0,
        costBasis: Double = 0,
        linkedAccountName: String = ""
    ) {
        self.id = id
        self.name = name
        self.categoryName = categoryName
        self.subtypeName = subtypeName
        self.currentValue = currentValue
        self.costBasis = costBasis
        self.linkedAccountName = linkedAccountName
    }
}
