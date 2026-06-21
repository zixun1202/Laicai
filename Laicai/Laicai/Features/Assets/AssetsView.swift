import SwiftUI
import SwiftData

struct AssetsView: View {
    @Query(sort: \AssetCategory.sortOrder) private var categories: [AssetCategory]
    @Query(sort: \Asset.name) private var assets: [Asset]
    @State private var showingCreateSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories, id: \.id) { category in
                    Section(category.name) {
                        let categoryAssets = assets.filter { $0.categoryName == category.name }

                        if categoryAssets.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("还没有录入资产")
                                    .foregroundStyle(.secondary)
                                Text(category.subtypes.joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            ForEach(categoryAssets, id: \.id) { asset in
                                NavigationLink {
                                    AssetEditorView(asset: asset)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(asset.name)
                                                .font(.headline)
                                            Spacer()
                                            Text("¥\(asset.currentValue, specifier: "%.0f")")
                                                .foregroundStyle(.primary)
                                        }

                                        Text("\(asset.subtypeName)\(asset.linkedAccountName.isEmpty ? "" : " · \(asset.linkedAccountName)")")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("资产")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增资产") {
                        showingCreateSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                AssetEditorView(preferredCategoryName: categories.first?.name)
            }
        }
    }
}
