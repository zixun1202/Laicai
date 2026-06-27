import SwiftData
import XCTest
@testable import Laicai

final class LedgerArchiveServiceTests: XCTestCase {
    func testArchiveRoundTripPreservesLedgerData() throws {
        let assetID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let transactionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let draftID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let date = Date(timeIntervalSince1970: 1_766_666_666)
        let asset = Asset(
            id: assetID,
            name: "美元现金",
            categoryName: "现金与账户",
            subtypeName: "现金",
            currentValue: 1288.5,
            costBasis: 1288.5,
            linkedAccountName: "钱包",
            currencyCode: "USD",
            quoteSymbol: "VOO",
            quoteMarket: .overseas
        )
        let transaction = TransactionRecord(
            id: transactionID,
            type: .income,
            amount: 88,
            date: date,
            categoryName: "工资",
            note: "兼职",
            currencyCode: "USD",
            linkedAssetID: assetID,
            assetCurrentValueDelta: 88
        )
        let draft = DraftEntry(
            id: draftID,
            sourceType: "voice",
            originalText: "午饭 38",
            suggestedType: .expense,
            amount: 38,
            note: "午饭",
            createdAt: date
        )
        let profile = UserProfile(defaultCurrency: "USD", onboardingCompleted: true)

        let archive = LedgerArchiveService.makeArchive(
            assets: [asset],
            transactions: [transaction],
            drafts: [draft],
            profile: profile,
            exportedAt: date
        )
        let encoded = try LedgerArchiveService.encode(archive)
        let decoded = try LedgerArchiveService.decode(encoded)

        XCTAssertEqual(decoded, archive)
        XCTAssertTrue(encoded.contains("\"defaultCurrency\" : \"USD\""))
        XCTAssertTrue(encoded.contains("\"linkedAssetID\" : \"11111111-1111-1111-1111-111111111111\""))
        XCTAssertTrue(encoded.contains("\"quoteSymbol\" : \"VOO\""))
        XCTAssertTrue(encoded.contains("\"quoteMarketRawValue\" : \"overseas\""))
    }

    func testImportArchiveCanReplaceExistingLedger() throws {
        let context = try makeContext()
        let oldAsset = Asset(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "旧账户",
            categoryName: "现金与账户",
            subtypeName: "银行卡",
            currentValue: 100
        )
        let profile = UserProfile(defaultCurrency: "CNY", onboardingCompleted: true)
        context.insert(oldAsset)
        context.insert(profile)
        try context.save()

        let newAssetID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let transactionID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let archive = LedgerArchive(
            appName: "Laicai",
            version: LedgerArchiveService.currentVersion,
            exportedAt: Date(timeIntervalSince1970: 1_766_666_666),
            defaultCurrency: "EUR",
            assets: [
                LedgerArchiveAsset(
                    id: newAssetID,
                    name: "欧元现金",
                    categoryName: "现金与账户",
                    subtypeName: "现金",
                    currentValue: 500,
                    costBasis: 500,
                    linkedAccountName: "钱包",
                    currencyCode: "EUR",
                    quoteSymbol: "IE00B3XXRP09",
                    quoteMarketRawValue: FundMarketRegion.overseas.rawValue
                )
            ],
            transactions: [
                LedgerArchiveTransaction(
                    id: transactionID,
                    typeRawValue: TransactionType.expense.rawValue,
                    amount: 38,
                    date: Date(timeIntervalSince1970: 1_766_666_667),
                    categoryName: "餐饮",
                    note: "午饭",
                    currencyCode: "EUR",
                    linkedAssetID: newAssetID,
                    assetCurrentValueDelta: -38,
                    assetCostBasisDelta: 0
                )
            ],
            drafts: []
        )

        let summary = LedgerArchiveService.importArchive(
            archive,
            into: context,
            replacingExisting: true,
            existingAssets: [oldAsset],
            existingTransactions: [],
            existingDrafts: [],
            profiles: [profile]
        )
        try context.save()

        let assets = try context.fetch(FetchDescriptor<Asset>())
        let transactions = try context.fetch(FetchDescriptor<TransactionRecord>())
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())

        XCTAssertEqual(summary, LedgerImportSummary(assetCount: 1, transactionCount: 1, draftCount: 0))
        XCTAssertEqual(assets.map(\.name), ["欧元现金"])
        XCTAssertEqual(assets.first?.currencyCode, "EUR")
        XCTAssertEqual(assets.first?.quoteSymbol, "IE00B3XXRP09")
        XCTAssertEqual(assets.first?.quoteMarket, .overseas)
        XCTAssertEqual(transactions.first?.linkedAssetID, newAssetID)
        XCTAssertEqual(profiles.first?.defaultCurrency, "EUR")
    }

    func testDecodeOldBackupWithoutQuoteFieldsStillImports() throws {
        let context = try makeContext()
        let oldBackup = """
        {
          "appName" : "Laicai",
          "assets" : [
            {
              "categoryName" : "投资资产",
              "costBasis" : 100,
              "currencyCode" : "CNY",
              "currentValue" : 120,
              "id" : "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD",
              "linkedAccountName" : "",
              "name" : "旧备份基金",
              "subtypeName" : "基金"
            }
          ],
          "defaultCurrency" : "CNY",
          "drafts" : [],
          "exportedAt" : "2026-06-26T12:00:00Z",
          "transactions" : [],
          "version" : 1
        }
        """

        let archive = try LedgerArchiveService.decode(oldBackup)
        LedgerArchiveService.importArchive(
            archive,
            into: context,
            replacingExisting: true,
            existingAssets: [],
            existingTransactions: [],
            existingDrafts: [],
            profiles: []
        )
        try context.save()

        let assets = try context.fetch(FetchDescriptor<Asset>())
        XCTAssertEqual(assets.first?.name, "旧备份基金")
        XCTAssertNil(assets.first?.quoteSymbol)
        XCTAssertEqual(assets.first?.quoteMarket, .china)
    }

    func testDecodeRejectsEmptyBackupText() {
        XCTAssertThrowsError(try LedgerArchiveService.decode("   ")) { error in
            XCTAssertEqual(error.localizedDescription, LedgerArchiveError.emptyInput.localizedDescription)
        }
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Asset.self,
            TransactionRecord.self,
            DraftEntry.self,
            UserProfile.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
