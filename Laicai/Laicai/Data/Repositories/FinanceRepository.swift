import Foundation
import SwiftData

@MainActor
final class FinanceRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchCategories() throws -> [AssetCategory] {
        let descriptor = FetchDescriptor<AssetCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        return try context.fetch(descriptor)
    }

    func fetchRecentTransactions(limit: Int = 5) throws -> [TransactionRecord] {
        var descriptor = FetchDescriptor<TransactionRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func insert(_ transaction: TransactionRecord) throws {
        context.insert(transaction)
        try context.save()
    }

    func insert(_ draft: DraftEntry) throws {
        context.insert(draft)
        try context.save()
    }
}
