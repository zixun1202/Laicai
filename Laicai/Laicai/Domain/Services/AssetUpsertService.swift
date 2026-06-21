import Foundation

struct AssetFormData {
    let name: String
    let categoryName: String
    let subtypeName: String
    let currentValue: Double
    let costBasis: Double
    let linkedAccountName: String
}

enum AssetUpsertService {
    static func apply(form: AssetFormData, to asset: Asset?) -> Asset {
        let target = asset ?? Asset(
            name: form.name,
            categoryName: form.categoryName,
            subtypeName: form.subtypeName,
            currentValue: form.currentValue,
            costBasis: form.costBasis,
            linkedAccountName: form.linkedAccountName
        )

        target.name = form.name
        target.categoryName = form.categoryName
        target.subtypeName = form.subtypeName
        target.currentValue = form.currentValue
        target.costBasis = form.costBasis
        target.linkedAccountName = form.linkedAccountName

        return target
    }
}
