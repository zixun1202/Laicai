import Foundation

enum TransactionImpactService {
    static func appliedAsset(for transaction: TransactionRecord, in assets: [Asset]) -> Asset? {
        guard let linkedAssetID = transaction.linkedAssetID else {
            return nil
        }

        return assets.first { $0.id == linkedAssetID }
    }

    static func applicableAssets(for type: TransactionType, in assets: [Asset]) -> [Asset] {
        assets.filter { asset in
            canApply(type, to: asset)
        }
    }

    static func canApply(_ type: TransactionType, to asset: Asset) -> Bool {
        switch type {
        case .income, .expense:
            return asset.categoryName == "现金与账户"
        case .investmentBuy, .investmentSell:
            return asset.categoryName == "投资资产"
        case .assetValueAdjustment:
            return asset.categoryName != "负债"
        case .liabilityCreate, .liabilityRepayment:
            return asset.categoryName == "负债"
        case .transfer:
            return false
        }
    }

    @discardableResult
    static func apply(_ transaction: TransactionRecord, to asset: Asset?) -> Bool {
        guard let asset, canApply(transaction.type, to: asset) else {
            return false
        }

        let currentValueBefore = asset.currentValue
        let costBasisBefore = asset.costBasis

        switch transaction.type {
        case .income:
            asset.currentValue += transaction.amount
        case .expense:
            asset.currentValue -= transaction.amount
        case .investmentBuy:
            asset.currentValue += transaction.amount
            asset.costBasis += transaction.amount
        case .investmentSell:
            asset.currentValue -= transaction.amount
            asset.costBasis = max(0, asset.costBasis - transaction.amount)
        case .assetValueAdjustment:
            asset.currentValue += transaction.amount
        case .liabilityCreate:
            asset.currentValue += transaction.amount
        case .liabilityRepayment:
            asset.currentValue = max(0, asset.currentValue - transaction.amount)
        case .transfer:
            break
        }

        transaction.linkedAssetID = asset.id
        transaction.assetCurrentValueDelta = asset.currentValue - currentValueBefore
        transaction.assetCostBasisDelta = asset.costBasis - costBasisBefore
        return true
    }

    @discardableResult
    static func reverse(_ transaction: TransactionRecord, from asset: Asset?) -> Bool {
        guard let asset, canApply(transaction.type, to: asset) else {
            return false
        }

        asset.currentValue -= transaction.assetCurrentValueDelta
        asset.costBasis -= transaction.assetCostBasisDelta

        return true
    }
}
