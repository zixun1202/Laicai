import SwiftUI
import SwiftData

struct AssetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetCategory.sortOrder) private var categories: [AssetCategory]
    @Query private var profiles: [UserProfile]
    let asset: Asset?
    let preferredCategoryName: String?
    let wrapsInNavigationStack: Bool
    @State private var name = ""
    @State private var categoryName = ""
    @State private var subtypeName = ""
    @State private var currentValue = ""
    @State private var costBasis = ""
    @State private var linkedAccountName = ""
    @State private var currencyCode = "CNY"
    @State private var quoteSymbol = ""
    @State private var quoteMarket = FundMarketRegion.china
    @State private var saveError: String?

    init(asset: Asset? = nil, preferredCategoryName: String? = nil, wrapsInNavigationStack: Bool = true) {
        self.asset = asset
        self.preferredCategoryName = preferredCategoryName
        self.wrapsInNavigationStack = wrapsInNavigationStack
        _name = State(initialValue: asset?.name ?? "")
        _categoryName = State(initialValue: asset?.categoryName ?? preferredCategoryName ?? "")
        _subtypeName = State(initialValue: asset?.subtypeName ?? "")
        _currentValue = State(initialValue: asset.map { Self.formatNumber($0.currentValue) } ?? "")
        _costBasis = State(initialValue: asset.map { Self.formatNumber($0.costBasis) } ?? "")
        _linkedAccountName = State(initialValue: asset?.linkedAccountName ?? "")
        _currencyCode = State(initialValue: asset?.currencyCode ?? "CNY")
        _quoteSymbol = State(initialValue: asset?.quoteSymbol ?? "")
        _quoteMarket = State(initialValue: asset?.quoteMarket ?? .china)
    }

    private var availableSubtypes: [String] {
        categories.first(where: { $0.name == categoryName })?.subtypes ?? []
    }

    private var parsedCurrentValue: Double? {
        Double(currentValue.replacingOccurrences(of: ",", with: ""))
    }

    private var parsedCostBasis: Double {
        let normalized = costBasis.replacingOccurrences(of: ",", with: "")
        if let value = Double(normalized), !normalized.isEmpty {
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

    private var supportsQuote: Bool {
        AssetUpsertService.supportsQuote(categoryName: categoryName, subtypeName: subtypeName)
    }

    var body: some View {
        Group {
            if wrapsInNavigationStack {
                NavigationStack {
                    editorContent
                }
            } else {
                editorContent
            }
        }
    }

    private var editorContent: some View {
        ScrollView {
            ReceiptPaper(tornEdges: false) {
                VStack(spacing: 20) {
                    TicketPageHeader(
                        title: asset == nil ? "新增资产" : "编辑资产",
                        subtitle: "ASSET FORM",
                        systemImage: "tray.full"
                    )

                    VStack(spacing: 7) {
                        ReceiptDashedDivider()
                        ReceiptInfoRow(label: "MODE", value: asset == nil ? "CREATE" : "UPDATE")
                        ReceiptInfoRow(label: "CATEGORY", value: categoryName.isEmpty ? "PICK ONE" : categoryName)
                        ReceiptInfoRow(label: "STATUS", value: canSave ? "READY" : "EDITING")
                        ReceiptDashedDivider()
                    }

                    receiptField(title: "资产名称", placeholder: "例如 招商银行卡", text: $name)

                    pickerBlock(title: "资产大类") {
                        Picker("资产大类", selection: $categoryName) {
                            ForEach(categories, id: \.id) { category in
                                Text(category.name).tag(category.name)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    pickerBlock(title: "资产小类") {
                        Picker("资产小类", selection: $subtypeName) {
                            ForEach(availableSubtypes, id: \.self) { subtype in
                                Text(subtype).tag(subtype)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if supportsQuote {
                        quoteBindingBlock
                    }

                    receiptField(title: "当前价值", placeholder: "0.00", text: $currentValue)
                        .keyboardType(.decimalPad)
                    receiptField(title: "成本", placeholder: "默认等于当前价值", text: $costBasis)
                        .keyboardType(.decimalPad)
                    pickerBlock(title: "币种") {
                        Picker("币种", selection: $currencyCode) {
                            ForEach(CurrencyFormatterService.supportedCurrencyCodes, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    receiptField(title: "关联账户", placeholder: "可选", text: $linkedAccountName)

                    if let saveError {
                        Text("· \(saveError)")
                            .font(ReceiptStyle.mono(12, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.fadedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ReceiptSolidDivider()
                    ReceiptActionButton(title: "保存资产小票", systemImage: "checkmark.seal.fill") {
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
        .navigationTitle(asset == nil ? "新增资产" : "编辑资产")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ReceiptStyle.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: normalizeSelection)
        .onChange(of: categoryName) { _, _ in
            normalizeSubtype()
            normalizeQuoteBinding()
        }
        .onChange(of: subtypeName) { _, _ in
            normalizeQuoteBinding()
        }
        .toolbar {
            if wrapsInNavigationStack {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundStyle(ReceiptStyle.paper)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(!canSave)
                .foregroundStyle(canSave ? ReceiptStyle.paper : ReceiptStyle.fadedInk)
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

    private var quoteBindingBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReceiptSectionLabel(title: "行情绑定")
            pickerBlock(title: "市场") {
                Picker("市场", selection: $quoteMarket) {
                    ForEach(FundMarketRegion.allCases, id: \.self) { market in
                        Text(market.displayName).tag(market)
                    }
                }
                .pickerStyle(.segmented)
            }
            receiptField(title: "行情代码", placeholder: quoteMarket == .china ? "例如 161725 / 000001" : "例如 VOO / QQQ", text: $quoteSymbol)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            Text(quoteSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "· 可留空，留空时仍按手动资产价值汇总" : "· 保存后会在投资页展示\(quoteMarket.displayName)走势")
                .font(ReceiptStyle.mono(12, weight: .semibold))
                .foregroundStyle(ReceiptStyle.fadedInk)
        }
    }

    private func normalizeSelection() {
        if categoryName.isEmpty {
            categoryName = preferredCategoryName ?? categories.first?.name ?? ""
        }
        if asset == nil {
            currencyCode = profiles.first?.defaultCurrency ?? currencyCode
        }
        normalizeSubtype()
        normalizeQuoteBinding()
    }

    private func normalizeSubtype() {
        if subtypeName.isEmpty || !availableSubtypes.contains(subtypeName) {
            subtypeName = availableSubtypes.first ?? ""
        }
    }

    private func normalizeQuoteBinding() {
        if !supportsQuote {
            quoteSymbol = ""
            quoteMarket = .china
        }
    }

    private func save() {
        guard let parsedCurrentValue else {
            return
        }

        let form = AssetFormData(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryName: categoryName,
            subtypeName: subtypeName,
            currentValue: parsedCurrentValue,
            costBasis: parsedCostBasis,
            linkedAccountName: linkedAccountName.trimmingCharacters(in: .whitespacesAndNewlines),
            currencyCode: currencyCode,
            quoteSymbol: quoteSymbol,
            quoteMarket: quoteMarket
        )
        let savedAsset = AssetUpsertService.apply(form: form, to: asset)
        if asset == nil {
            modelContext.insert(savedAsset)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "保存失败，请稍后重试"
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
