import Foundation
import SwiftData

struct LedgerArchive: Codable, Equatable {
    var appName: String
    var version: Int
    var exportedAt: Date
    var defaultCurrency: String
    var assets: [LedgerArchiveAsset]
    var transactions: [LedgerArchiveTransaction]
    var drafts: [LedgerArchiveDraft]
}

struct LedgerArchiveAsset: Codable, Equatable {
    var id: UUID
    var name: String
    var categoryName: String
    var subtypeName: String
    var currentValue: Double
    var costBasis: Double
    var linkedAccountName: String
    var currencyCode: String
    var quoteSymbol: String?
    var quoteMarketRawValue: String?
}

struct LedgerArchiveTransaction: Codable, Equatable {
    var id: UUID
    var typeRawValue: String
    var amount: Double
    var date: Date
    var categoryName: String
    var note: String
    var currencyCode: String
    var linkedAssetID: UUID?
    var assetCurrentValueDelta: Double
    var assetCostBasisDelta: Double
}

struct LedgerArchiveDraft: Codable, Equatable {
    var id: UUID
    var sourceType: String
    var originalText: String
    var suggestedTypeRawValue: String
    var amount: Double
    var note: String
    var createdAt: Date
}

struct LedgerImportSummary: Equatable {
    var assetCount: Int
    var transactionCount: Int
    var draftCount: Int
}

enum LedgerArchiveError: LocalizedError {
    case emptyInput
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "备份文本为空"
        case .unsupportedVersion(let version):
            return "备份版本 \(version) 暂不支持"
        }
    }
}

enum LedgerArchiveService {
    static let currentVersion = 1
    private static let appName = "Laicai"

    static func makeArchive(
        assets: [Asset],
        transactions: [TransactionRecord],
        drafts: [DraftEntry],
        profile: UserProfile?,
        exportedAt: Date = .now
    ) -> LedgerArchive {
        LedgerArchive(
            appName: appName,
            version: currentVersion,
            exportedAt: exportedAt,
            defaultCurrency: profile?.defaultCurrency ?? "CNY",
            assets: assets
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map(LedgerArchiveAsset.init),
            transactions: transactions
                .sorted { $0.date > $1.date }
                .map(LedgerArchiveTransaction.init),
            drafts: drafts
                .sorted { $0.createdAt > $1.createdAt }
                .map(LedgerArchiveDraft.init)
        )
    }

    static func encode(_ archive: LedgerArchive) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(archive)
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ text: String) throws -> LedgerArchive {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw LedgerArchiveError.emptyInput
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(LedgerArchive.self, from: Data(trimmedText.utf8))
        guard archive.version <= currentVersion else {
            throw LedgerArchiveError.unsupportedVersion(archive.version)
        }
        return archive
    }

    @discardableResult
    static func importArchive(
        _ archive: LedgerArchive,
        into modelContext: ModelContext,
        replacingExisting: Bool,
        existingAssets: [Asset],
        existingTransactions: [TransactionRecord],
        existingDrafts: [DraftEntry],
        profiles: [UserProfile]
    ) -> LedgerImportSummary {
        if replacingExisting {
            existingDrafts.forEach(modelContext.delete)
            existingTransactions.forEach(modelContext.delete)
            existingAssets.forEach(modelContext.delete)
        }

        let assetIndex = replacingExisting ? [:] : Dictionary(uniqueKeysWithValues: existingAssets.map { ($0.id, $0) })
        let transactionIndex = replacingExisting ? [:] : Dictionary(uniqueKeysWithValues: existingTransactions.map { ($0.id, $0) })
        let draftIndex = replacingExisting ? [:] : Dictionary(uniqueKeysWithValues: existingDrafts.map { ($0.id, $0) })

        archive.assets.forEach { item in
            if let asset = assetIndex[item.id] {
                item.apply(to: asset)
            } else {
                modelContext.insert(item.makeAsset())
            }
        }

        archive.transactions.forEach { item in
            if let transaction = transactionIndex[item.id] {
                item.apply(to: transaction)
            } else {
                modelContext.insert(item.makeTransaction())
            }
        }

        archive.drafts.forEach { item in
            if let draft = draftIndex[item.id] {
                item.apply(to: draft)
            } else {
                modelContext.insert(item.makeDraft())
            }
        }

        let profile = profiles.first ?? UserProfile(defaultCurrency: archive.defaultCurrency, onboardingCompleted: true)
        profile.defaultCurrency = archive.defaultCurrency
        profile.onboardingCompleted = true
        if profiles.first == nil {
            modelContext.insert(profile)
        }

        return LedgerImportSummary(
            assetCount: archive.assets.count,
            transactionCount: archive.transactions.count,
            draftCount: archive.drafts.count
        )
    }
}

private extension LedgerArchiveAsset {
    init(asset: Asset) {
        self.init(
            id: asset.id,
            name: asset.name,
            categoryName: asset.categoryName,
            subtypeName: asset.subtypeName,
            currentValue: asset.currentValue,
            costBasis: asset.costBasis,
            linkedAccountName: asset.linkedAccountName,
            currencyCode: asset.currencyCode ?? "CNY",
            quoteSymbol: asset.quoteSymbol,
            quoteMarketRawValue: asset.quoteMarketRawValue
        )
    }

    func makeAsset() -> Asset {
        Asset(
            id: id,
            name: name,
            categoryName: categoryName,
            subtypeName: subtypeName,
            currentValue: currentValue,
            costBasis: costBasis,
            linkedAccountName: linkedAccountName,
            currencyCode: currencyCode,
            quoteSymbol: quoteSymbol,
            quoteMarket: FundMarketRegion(rawValue: quoteMarketRawValue ?? "") ?? .china
        )
    }

    func apply(to asset: Asset) {
        asset.name = name
        asset.categoryName = categoryName
        asset.subtypeName = subtypeName
        asset.currentValue = currentValue
        asset.costBasis = costBasis
        asset.linkedAccountName = linkedAccountName
        asset.currencyCode = currencyCode
        asset.quoteSymbol = quoteSymbol
        asset.quoteMarketRawValue = quoteMarketRawValue
    }
}

private extension LedgerArchiveTransaction {
    init(transaction: TransactionRecord) {
        self.init(
            id: transaction.id,
            typeRawValue: transaction.typeRawValue,
            amount: transaction.amount,
            date: transaction.date,
            categoryName: transaction.categoryName,
            note: transaction.note,
            currencyCode: transaction.currencyCode ?? "CNY",
            linkedAssetID: transaction.linkedAssetID,
            assetCurrentValueDelta: transaction.assetCurrentValueDelta,
            assetCostBasisDelta: transaction.assetCostBasisDelta
        )
    }

    func makeTransaction() -> TransactionRecord {
        TransactionRecord(
            id: id,
            type: TransactionType(rawValue: typeRawValue) ?? .expense,
            amount: amount,
            date: date,
            categoryName: categoryName,
            note: note,
            currencyCode: currencyCode,
            linkedAssetID: linkedAssetID,
            assetCurrentValueDelta: assetCurrentValueDelta,
            assetCostBasisDelta: assetCostBasisDelta
        )
    }

    func apply(to transaction: TransactionRecord) {
        transaction.typeRawValue = typeRawValue
        transaction.amount = amount
        transaction.date = date
        transaction.categoryName = categoryName
        transaction.note = note
        transaction.currencyCode = currencyCode
        transaction.linkedAssetID = linkedAssetID
        transaction.assetCurrentValueDelta = assetCurrentValueDelta
        transaction.assetCostBasisDelta = assetCostBasisDelta
    }
}

private extension LedgerArchiveDraft {
    init(draft: DraftEntry) {
        self.init(
            id: draft.id,
            sourceType: draft.sourceType,
            originalText: draft.originalText,
            suggestedTypeRawValue: draft.suggestedTypeRawValue,
            amount: draft.amount,
            note: draft.note,
            createdAt: draft.createdAt
        )
    }

    func makeDraft() -> DraftEntry {
        DraftEntry(
            id: id,
            sourceType: sourceType,
            originalText: originalText,
            suggestedType: TransactionType(rawValue: suggestedTypeRawValue) ?? .expense,
            amount: amount,
            note: note,
            createdAt: createdAt
        )
    }

    func apply(to draft: DraftEntry) {
        draft.sourceType = sourceType
        draft.originalText = originalText
        draft.suggestedTypeRawValue = suggestedTypeRawValue
        draft.amount = amount
        draft.note = note
        draft.createdAt = createdAt
    }
}
