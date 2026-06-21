import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house")
                }

            AssetsView()
                .tabItem {
                    Label("资产", systemImage: "tray.full")
                }

            BookkeepingView()
                .tabItem {
                    Label("记账", systemImage: "square.and.pencil")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}
