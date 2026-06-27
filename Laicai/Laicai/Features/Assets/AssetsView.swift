import SwiftUI
import SwiftData

struct AssetsView: View {
    @Query(sort: \AssetCategory.sortOrder) private var categories: [AssetCategory]
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query private var profiles: [UserProfile]
    @State private var presentedSheet: AssetsSheet?

    private var summary: NetWorthSummary {
        PortfolioSummaryService.netWorthSummary(for: assets)
    }

    private var currencyCode: String {
        profiles.first?.defaultCurrency ?? "CNY"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ReceiptPaper(tornEdges: false) {
                    VStack(spacing: 20) {
                        TicketPageHeader(title: "资产账本", subtitle: "BALANCE DASH", systemImage: "tray.full")

                        VStack(spacing: 7) {
                            ReceiptDashedDivider()
                            ReceiptInfoRow(label: "CATEGORIES", value: String(format: "%02d", categories.count))
                            ReceiptInfoRow(label: "ASSET ITEMS", value: String(format: "%02d", assets.count))
                            ReceiptInfoRow(label: "ASSETS", value: money(summary.totalAssets))
                            ReceiptInfoRow(label: "LIABILITIES", value: money(summary.totalLiabilities))
                            ReceiptInfoRow(label: "NET WORTH", value: money(summary.netWorth))
                            ReceiptDashedDivider()
                        }

                        ReceiptActionButton(title: "新增资产", systemImage: "plus.circle.fill") {
                            presentedSheet = .create
                        }

                        VStack(spacing: 18) {
                            ForEach(categories, id: \.id) { category in
                                assetSection(for: category)
                            }
                        }

                        ReceiptDashedDivider()
                        ReceiptInfoRow(label: "UPDATED", value: "LOCAL LEDGER")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(ReceiptStyle.background.ignoresSafeArea())
            .navigationTitle("资产")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ReceiptStyle.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentedSheet = .create
                    } label: {
                        Label("新增资产", systemImage: "plus")
                    }
                    .foregroundStyle(ReceiptStyle.paper)
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .create:
                    AssetEditorView(preferredCategoryName: categories.first?.name)
                }
            }
        }
    }

    private func assetSection(for category: AssetCategory) -> some View {
        let categoryAssets = assets.filter { $0.categoryName == category.name }

        return VStack(alignment: .leading, spacing: 12) {
            ReceiptSectionLabel(title: category.name)

            if categoryAssets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("还没有录入资产")
                        .font(ReceiptStyle.mono(14, weight: .bold))
                    Text("· \(category.subtypes.joined(separator: " · "))")
                        .font(ReceiptStyle.mono(12, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                }
                .foregroundStyle(ReceiptStyle.ink)
            } else {
                VStack(spacing: 14) {
                    ForEach(Array(categoryAssets.enumerated()), id: \.element.id) { index, asset in
                        NavigationLink {
                            AssetEditorView(asset: asset, wrapsInNavigationStack: false)
                        } label: {
                            VStack(spacing: 12) {
                                HStack(alignment: .top) {
                                    Text(String(format: "%02d", index + 1))
                                        .frame(width: 34, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(asset.name)
                                            .fontWeight(.bold)
                                        Text("· \(asset.subtypeName)\(asset.linkedAccountName.isEmpty ? "" : " / \(asset.linkedAccountName)")")
                                            .foregroundStyle(ReceiptStyle.fadedInk)
                                    }

                                    Spacer()
                                    Text(money(asset.currentValue, currencyCode: asset.currencyCode))
                                }
                                .font(ReceiptStyle.mono(13, weight: .semibold))
                                .foregroundStyle(ReceiptStyle.ink)

                                if index < categoryAssets.count - 1 {
                                    ReceiptDashedDivider()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func money(_ value: Decimal) -> String {
        CurrencyFormatterService.money(value, currencyCode: currencyCode)
    }

    private func money(_ value: Double, currencyCode: String? = nil) -> String {
        CurrencyFormatterService.money(value, currencyCode: currencyCode ?? self.currencyCode)
    }
}

private enum AssetsSheet: Identifiable {
    case create

    var id: String {
        switch self {
        case .create:
            return "create"
        }
    }
}
