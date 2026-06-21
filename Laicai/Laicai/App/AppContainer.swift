import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppContainer {
    static let shared = AppContainer()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            UserProfile.self,
            AssetCategory.self,
            Account.self,
            Asset.self,
            TransactionRecord.self,
            DraftEntry.self,
            HoldingSnapshot.self
        ])

        do {
            modelContainer = try ModelContainer(for: schema, configurations: ModelConfiguration("Laicai"))
            try DefaultCategorySeeder.seedIfNeeded(context: modelContainer.mainContext)
        } catch {
            fatalError("Failed to initialize app container: \(error)")
        }
    }
}
