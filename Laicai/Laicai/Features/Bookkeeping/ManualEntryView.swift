import SwiftUI
import SwiftData

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query private var profiles: [UserProfile]
    @State private var amount = ""
    @State private var note = ""
    @State private var selectedType: TransactionType = .expense
    @State private var categoryName = TransactionCategoryCatalog.defaultCategory(for: .expense)
    @State private var selectedAssetID = ""
    @State private var currencyCode = "CNY"
    @State private var saveError: String?

    private var categoryOptions: [String] {
        TransactionCategoryCatalog.categories(for: selectedType)
    }

    private var canSave: Bool {
        Double(amount.replacingOccurrences(of: ",", with: "")) != nil
    }

    private var selectedAsset: Asset? {
        applicableAssets.first { $0.id.uuidString == selectedAssetID }
    }

    private var applicableAssets: [Asset] {
        TransactionImpactService.applicableAssets(for: selectedType, in: assets)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ReceiptPaper(tornEdges: false) {
                    VStack(spacing: 20) {
                        TicketPageHeader(title: "手工记账", subtitle: "MANUAL ENTRY", systemImage: "square.and.pencil")

                        VStack(spacing: 7) {
                            ReceiptDashedDivider()
                            ReceiptInfoRow(label: "DATE", value: Self.dateFormatter.string(from: .now))
                            ReceiptInfoRow(label: "SOURCE", value: "MANUAL")
                            ReceiptInfoRow(label: "STATUS", value: canSave ? "READY" : "EDITING")
                            ReceiptDashedDivider()
                        }

                        receiptField(title: "金额", placeholder: "例如 38.00", text: $amount)
                            .keyboardType(.decimalPad)

                        pickerBlock(title: "币种") {
                            Picker("币种", selection: $currencyCode) {
                                ForEach(CurrencyFormatterService.supportedCurrencyCodes, id: \.self) { code in
                                    Text(code).tag(code)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        pickerBlock(title: "类型") {
                            Picker("类型", selection: $selectedType) {
                                ForEach(TransactionType.allCases, id: \.self) { type in
                                    Text(type.displayName)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        pickerBlock(title: "分类") {
                            Picker("分类", selection: $categoryName) {
                                ForEach(categoryOptions, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        pickerBlock(title: "关联资产") {
                            Picker("关联资产", selection: $selectedAssetID) {
                                Text("不调整资产余额").tag("")
                                ForEach(applicableAssets, id: \.id) { asset in
                                    Text(asset.name).tag(asset.id.uuidString)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        receiptField(title: "备注", placeholder: "早餐、工资、基金定投...", text: $note)

                        if let saveError {
                            Text("· \(saveError)")
                                .font(ReceiptStyle.mono(12, weight: .semibold))
                                .foregroundStyle(ReceiptStyle.fadedInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ReceiptSolidDivider()
                        ReceiptActionButton(title: "打印到今日小票", systemImage: "checkmark.seal.fill") {
                            save()
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.45)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(ReceiptStyle.background.ignoresSafeArea())
            .navigationTitle("手工录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ReceiptStyle.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundStyle(ReceiptStyle.paper)
                }
            }
            .onAppear(perform: normalizeForm)
            .onChange(of: selectedType) { _, _ in
                normalizeCategory()
                normalizeAsset()
            }
        }
    }

    private func receiptField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ReceiptStyle.mono(13, weight: .bold))
            TextField(placeholder, text: text, axis: .vertical)
                .font(ReceiptStyle.mono(16, weight: .semibold))
                .foregroundStyle(ReceiptStyle.ink)
                .accessibilityLabel(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .foregroundStyle(ReceiptStyle.ink)
    }

    private func pickerBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ReceiptStyle.mono(13, weight: .bold))
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .foregroundStyle(ReceiptStyle.ink)
    }

    private func normalizeCategory() {
        if !categoryOptions.contains(categoryName) {
            categoryName = TransactionCategoryCatalog.defaultCategory(for: selectedType)
        }
    }

    private func normalizeForm() {
        currencyCode = profiles.first?.defaultCurrency ?? currencyCode
        normalizeCategory()
        normalizeAsset()
    }

    private func normalizeAsset() {
        if !selectedAssetID.isEmpty && selectedAsset == nil {
            selectedAssetID = ""
        }
    }

    private func save() {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: "")) else {
            return
        }

        let record = TransactionRecord(
            type: selectedType,
            amount: value,
            date: .now,
            categoryName: categoryName,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            currencyCode: currencyCode
        )
        modelContext.insert(record)
        if TransactionImpactService.apply(record, to: selectedAsset), let selectedAsset {
            record.linkedAssetID = selectedAsset.id
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "保存失败，请稍后重试"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()
}
