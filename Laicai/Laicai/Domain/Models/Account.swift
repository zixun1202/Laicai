import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    var name: String
    var categoryName: String
    var subtypeName: String
    var balance: Double
    var note: String

    init(
        id: UUID = UUID(),
        name: String,
        categoryName: String,
        subtypeName: String,
        balance: Double = 0,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.categoryName = categoryName
        self.subtypeName = subtypeName
        self.balance = balance
        self.note = note
    }
}
