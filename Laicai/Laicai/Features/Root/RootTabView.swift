import SwiftUI
import UIKit

struct RootTabView: View {
    @State private var selectedTab: RootTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
            HomeView()
                .tag(RootTab.home)
                .tabItem {
                    Label("首页", systemImage: "house")
                }

            AssetsView()
                .tag(RootTab.assets)
                .tabItem {
                    Label("资产", systemImage: "tray.full")
                }

            BookkeepingView()
                .tag(RootTab.bookkeeping)
                .tabItem {
                    Label("记账", systemImage: "square.and.pencil")
                }

            SettingsView()
                .tag(RootTab.settings)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
            }
            .tint(ReceiptStyle.paper)

            Button {
                selectedTab = .bookkeeping
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .black))
                        .frame(height: 25)
                    Text("新增")
                        .font(ReceiptStyle.mono(10, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(ReceiptStyle.ink)
                .frame(width: 64, height: 52)
                .background(ReceiptStyle.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(ReceiptStyle.ink.opacity(0.18), lineWidth: ReceiptStyle.softOutlineWidth)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 9)
            .accessibilityLabel("快速记账")
        }
        .onAppear(perform: configureTabBar)
    }

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(ReceiptStyle.panel.opacity(0.88))
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(ReceiptStyle.ink)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(ReceiptStyle.ink)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(ReceiptStyle.fadedInk)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(ReceiptStyle.fadedInk)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

private enum RootTab: Hashable {
    case home
    case assets
    case bookkeeping
    case settings
}
