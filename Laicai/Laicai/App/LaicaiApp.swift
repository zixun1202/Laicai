import SwiftUI
import SwiftData

@main
struct LaicaiApp: App {
    private let container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(container)
        }
        .modelContainer(container.modelContainer)
    }
}
