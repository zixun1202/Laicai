import SwiftUI
import SwiftData

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    let transaction: TransactionRecord
    @State private var amountText: String
    @State private var selectedType: TransactionType
    @State private var categoryName: String
    @State private var note: String
    @State private var currencyCode: String
    @State private var selectedAssetID: String
    @State private var saveError: String?

    init(transaction: TransactionRecord) {
        self.transaction = transaction
        _amountText = State(initialValue: TransactionEditorView.formattedAmount(transaction.amount))
        _selectedType = State(initialValue: transaction.type)
        _categoryName = State(initialValue: transaction.categoryName)
        _note = State(initialValue: transaction.note)
        _currencyCode = State(initialValue: transaction.currencyCode ?? "CNY")
        _selectedAssetID = State(initialValue: transaction.linkedAssetID?.uuidString ?? "")
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ""))
    }

    private var canSave: Bool {
        parsedAmount != nil && !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var categoryOptions: [String] {
        TransactionCategoryCatalog.categories(for: selectedType)
    }

    private var applicableAssets: [Asset] {
        TransactionImpactService.applicableAssets(for: selectedType, in: assets)
    }

    private var selectedAsset: Asset? {
        applicableAssets.first { $0.id.uuidString == selectedAssetID }
    }

    var body: some View {
        ScrollView {
            ReceiptPaper(tornEdges: false) {
                VStack(spacing: 20) {
                    TicketPageHeader(title: "编辑交易", subtitle: "LEDGER EDIT", systemImage: "pencil.and.list.clipboard")

                    VStack(spacing: 7) {
                        ReceiptDashedDivider()
                        ReceiptInfoRow(label: "DATE", value: Self.dateFormatter.string(from: transaction.date))
                        ReceiptInfoRow(label: "AMOUNT", value: CurrencyFormatterService.money(parsedAmount ?? transaction.amount, currencyCode: currencyCode, minimumFractionDigits: 2, maximumFractionDigits: 2))
                        ReceiptInfoRow(label: "STATUS", value: canSave ? "READY" : "CHECK")
                        ReceiptDashedDivider()
                    }

                    receiptField(title: "金额", placeholder: "金额", text: $amountText)
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

                    receiptField(title: "备注", placeholder: "备注", text: $note)

                    if let saveError {
                        Text("· \(saveError)")
                            .font(ReceiptStyle.mono(12, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.fadedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ReceiptSolidDivider()
                    ReceiptActionButton(title: "保存重印", systemImage: "checkmark.seal.fill") {
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
        .navigationTitle("编辑交易")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ReceiptStyle.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: normalizeForm)
        .onChange(of: selectedType) { _, _ in
            normalizeCategory()
            normalizeAsset()
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

    private func normalizeForm() {
        normalizeCategory()
        normalizeAsset()
    }

    private func normalizeCategory() {
        if !categoryOptions.contains(categoryName) {
            categoryName = TransactionCategoryCatalog.defaultCategory(for: selectedType)
        }
    }

    private func normalizeAsset() {
        if !selectedAssetID.isEmpty && selectedAsset == nil {
            selectedAssetID = ""
        }
    }

    private func save() {
        guard let parsedAmount else {
            return
        }

        if let originalAsset = TransactionImpactService.appliedAsset(for: transaction, in: assets) {
            TransactionImpactService.reverse(transaction, from: originalAsset)
        } else if transaction.linkedAssetID != nil {
            saveError = "原关联资产不存在，无法重算余额"
            return
        }

        transaction.type = selectedType
        transaction.amount = parsedAmount
        transaction.categoryName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.currencyCode = currencyCode
        transaction.linkedAssetID = nil

        if TransactionImpactService.apply(transaction, to: selectedAsset), let selectedAsset {
            transaction.linkedAssetID = selectedAsset.id
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "保存失败，请稍后重试"
        }
    }

    private static func formattedAmount(_ amount: Double) -> String {
        if amount.rounded() == amount {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()
}
