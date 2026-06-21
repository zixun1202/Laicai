import Foundation
import SwiftData

@Model
final class AssetCategory {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var sortOrder: Int
    var subtypesRawValue: String

    var subtypes: [String] {
        get {
            subtypesRawValue
                .split(separator: "|")
                .map(String.init)
        }
        set {
            subtypesRawValue = newValue.joined(separator: "|")
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        sortOrder: Int,
        subtypes: [String]
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.subtypesRawValue = subtypes.joined(separator: "|")
    }
}
