import SwiftUI
import SwiftData

struct AssetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetCategory.sortOrder) private var categories: [AssetCategory]
    let asset: Asset?
    let preferredCategoryName: String?
    @State private var name = ""
    @State private var categoryName = ""
    @State private var subtypeName = ""
    @State private var currentValue = ""
    @State private var costBasis = ""
    @State private var linkedAccountName = ""

    init(asset: Asset? = nil, preferredCategoryName: String? = nil) {
        self.asset = asset
        self.preferredCategoryName = preferredCategoryName
        _name = State(initialValue: asset?.name ?? "")
        _categoryName = State(initialValue: asset?.categoryName ?? preferredCategoryName ?? "")
        _subtypeName = State(initialValue: asset?.subtypeName ?? "")
        _currentValue = State(initialValue: asset.map { Self.formatNumber($0.currentValue) } ?? "")
        _costBasis = State(initialValue: asset.map { Self.formatNumber($0.costBasis) } ?? "")
        _linkedAccountName = State(initialValue: asset?.linkedAccountName ?? "")
    }

    private var availableSubtypes: [String] {
        categories.first(where: { $0.name == categoryName })?.subtypes ?? []
    }

    private var parsedCurrentValue: Double? {
        Double(currentValue)
    }

    private var parsedCostBasis: Double {
        if let value = Double(costBasis), !costBasis.isEmpty {
            return value
        }
        return parsedCurrentValue ?? 0
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !categoryName.isEmpty &&
        !subtypeName.isEmpty &&
        parsedCurrentValue != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("资产名称", text: $name)

                Picker("资产大类", selection: $categoryName) {
                    ForEach(categories, id: \.id) { category in
                        Text(category.name).tag(category.name)
                    }
                }

                Picker("资产小类", selection: $subtypeName) {
                    ForEach(availableSubtypes, id: \.self) { subtype in
                        Text(subtype).tag(subtype)
                    }
                }

                TextField("当前价值", text: $currentValue)
                    .keyboardType(.decimalPad)
                TextField("成本", text: $costBasis)
                    .keyboardType(.decimalPad)
                TextField("关联账户", text: $linkedAccountName)
            }
            .navigationTitle(asset == nil ? "新增资产" : "编辑资产")
            .onAppear {
                if categoryName.isEmpty {
                    categoryName = categories.first?.name ?? ""
                }
                if subtypeName.isEmpty || !availableSubtypes.contains(subtypeName) {
                    subtypeName = availableSubtypes.first ?? ""
                }
            }
            .onChange(of: categoryName) { _, _ in
                if !availableSubtypes.contains(subtypeName) {
                    subtypeName = availableSubtypes.first ?? ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let parsedCurrentValue else {
                            return
                        }

                        let form = AssetFormData(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            categoryName: categoryName,
                            subtypeName: subtypeName,
                            currentValue: parsedCurrentValue,
                            costBasis: parsedCostBasis,
                            linkedAccountName: linkedAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        let savedAsset = AssetUpsertService.apply(form: form, to: asset)
                        if asset == nil {
                            modelContext.insert(savedAsset)
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
