import SwiftUI
import SwiftData

struct TransactionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]
    @Query(sort: \Asset.name) private var assets: [Asset]
    @State private var pendingDeletion: PendingDeletion?
    @State private var statusMessage: String?
    @State private var searchText = ""
    @State private var selectedTypeRawValue = LedgerTypeFilter.all
    @State private var selectedCurrencyCode = LedgerCurrencyFilter.all
    @State private var selectedDateRange = LedgerDateRangeFilter.all

    var body: some View {
        ScrollView {
            ReceiptPaper(tornEdges: false) {
                VStack(spacing: 20) {
                    TicketPageHeader(title: "交易历史", subtitle: "LEDGER HISTORY", systemImage: "list.bullet.rectangle")

                    VStack(spacing: 7) {
                        ReceiptDashedDivider()
                        ReceiptInfoRow(label: "ENTRIES", value: String(format: "%02d / %02d", filteredTransactions.count, transactions.count))
                        ReceiptInfoRow(label: "SOURCE", value: "LOCAL LEDGER")
                        ReceiptInfoRow(label: "STATUS", value: statusLabel)
                        ReceiptDashedDivider()
                    }

                    filterPanel
                    summaryPanel

                    if transactions.isEmpty {
                        emptyState(
                            title: "还没有交易记录",
                            detail: "手工、语音或截图确认后会出现在这里"
                        )
                    } else if filteredTransactions.isEmpty {
                        emptyState(
                            title: "没有符合筛选的记录",
                            detail: "调整关键词、类型、币种或日期范围再试试"
                        )
                    } else {
                        transactionList
                    }

                    if let statusMessage {
                        Text("· \(statusMessage)")
                            .font(ReceiptStyle.mono(12, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.fadedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ReceiptSolidDivider()
                    ReceiptInfoRow(label: "TOTAL RECORDS", value: String(format: "%02d", transactions.count))
                    ReceiptInfoRow(label: "VIEW MODE", value: hasActiveFilter ? "FILTERED" : "ALL")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(ReceiptStyle.background.ignoresSafeArea())
        .navigationTitle("交易历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ReceiptStyle.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert(item: $pendingDeletion) { pendingDeletion in
            Alert(
                title: Text("删除这条交易？"),
                message: Text("如果它曾关联资产余额，会同时尝试回滚对应影响。"),
                primaryButton: .destructive(Text("删除")) {
                    deleteTransaction(id: pendingDeletion.id)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var statusLabel: String {
        if transactions.isEmpty {
            return "EMPTY"
        }
        if hasActiveFilter {
            return filteredTransactions.isEmpty ? "NO MATCH" : "FILTERED"
        }
        return "READY"
    }

    private var hasActiveFilter: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedTypeRawValue != LedgerTypeFilter.all ||
            selectedCurrencyCode != LedgerCurrencyFilter.all ||
            selectedDateRange != .all
    }

    private var filteredTransactions: [TransactionRecord] {
        transactions.filter { transaction in
            matchesSearch(transaction) &&
                matchesType(transaction) &&
                matchesCurrency(transaction) &&
                selectedDateRange.contains(transaction.date)
        }
    }

    private var currencySummaries: [LedgerCurrencySummary] {
        let grouped = Dictionary(grouping: filteredTransactions) { $0.currencyCode ?? "CNY" }
        return grouped.keys.sorted().map { currencyCode in
            let records = grouped[currencyCode] ?? []
            return LedgerCurrencySummary(
                currencyCode: currencyCode,
                income: records
                    .filter { $0.type == .income || $0.type == .investmentSell }
                    .map(\.amount)
                    .reduce(0, +),
                expense: records
                    .filter { $0.type == .expense || $0.type == .investmentBuy || $0.type == .liabilityRepayment }
                    .map(\.amount)
                    .reduce(0, +),
                net: records
                    .map { signedAmount(for: $0) }
                    .reduce(0, +)
            )
        }
    }

    private var filterPanel: some View {
        VStack(spacing: 12) {
            ReceiptSectionLabel(title: "筛选")

            TextField("搜索备注 / 分类 / 资产", text: $searchText)
                .font(ReceiptStyle.mono(14, weight: .semibold))
                .foregroundStyle(ReceiptStyle.ink)
                .submitLabel(.search)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("搜索交易")

            HStack(spacing: 10) {
                menuPicker(
                    title: "类型",
                    selection: selectedTypeTitle,
                    systemImage: "line.3.horizontal.decrease.circle"
                ) {
                    Button("全部类型") {
                        selectedTypeRawValue = LedgerTypeFilter.all
                    }
                    ForEach(TransactionType.allCases, id: \.rawValue) { type in
                        Button(type.displayName) {
                            selectedTypeRawValue = type.rawValue
                        }
                    }
                }

                menuPicker(
                    title: "币种",
                    selection: selectedCurrencyTitle,
                    systemImage: "creditcard"
                ) {
                    Button("全部币种") {
                        selectedCurrencyCode = LedgerCurrencyFilter.all
                    }
                    ForEach(CurrencyFormatterService.supportedCurrencyCodes, id: \.self) { code in
                        Button(code) {
                            selectedCurrencyCode = code
                        }
                    }
                }
            }

            Picker("日期范围", selection: $selectedDateRange) {
                ForEach(LedgerDateRangeFilter.allCases, id: \.self) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if hasActiveFilter {
                Button {
                    resetFilters()
                } label: {
                    Label("清除筛选", systemImage: "xmark.circle")
                        .font(ReceiptStyle.mono(12, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ReceiptStyle.ink)
            }
        }
        .foregroundStyle(ReceiptStyle.ink)
    }

    private var summaryPanel: some View {
        VStack(spacing: 10) {
            ReceiptSectionLabel(title: "汇总")

            if currencySummaries.isEmpty {
                ReceiptInfoRow(label: "MATCHED", value: "00")
            } else {
                ReceiptInfoRow(label: "MATCHED", value: String(format: "%02d", filteredTransactions.count))
                ForEach(currencySummaries) { summary in
                    VStack(spacing: 8) {
                        ReceiptInfoRow(label: "\(summary.currencyCode) NET", value: money(summary.net, currencyCode: summary.currencyCode, digits: 2))
                        HStack {
                            Text("IN \(money(summary.income, currencyCode: summary.currencyCode, digits: 0))")
                            Spacer()
                            Text("OUT \(money(summary.expense, currencyCode: summary.currencyCode, digits: 0))")
                        }
                        .font(ReceiptStyle.mono(11, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                    }
                }
            }
        }
    }

    private func emptyState(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ReceiptStyle.mono(16, weight: .bold))
            Text("· \(detail)")
                .font(ReceiptStyle.mono(13, weight: .semibold))
                .foregroundStyle(ReceiptStyle.fadedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(ReceiptStyle.ink)
    }

    private var transactionList: some View {
        let rows = filteredTransactions
        return VStack(spacing: 16) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, transaction in
                VStack(spacing: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        NavigationLink {
                            TransactionEditorView(transaction: transaction)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(String(format: "%02d", index + 1))
                                    .frame(width: 34, alignment: .leading)

                                VStack(alignment: .leading, spacing: 7) {
                                    Text(transaction.note.isEmpty ? transaction.categoryName : transaction.note)
                                        .fontWeight(.bold)
                                    Text("· \(transaction.type.displayName) \(money(transaction.amount, currencyCode: transaction.currencyCode, digits: 2))")
                                        .foregroundStyle(ReceiptStyle.fadedInk)
                                    Text("· \(Self.dateFormatter.string(from: transaction.date)) / \(assetLabel(for: transaction))")
                                        .font(ReceiptStyle.mono(11, weight: .semibold))
                                        .foregroundStyle(ReceiptStyle.fadedInk)
                                }

                                Spacer()

                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(ReceiptStyle.fadedInk)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            pendingDeletion = PendingDeletion(id: transaction.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(ReceiptStyle.ink)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(ReceiptStyle.ink.opacity(0.42), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除交易")
                        .frame(width: 34, height: 34)
                    }
                    .font(ReceiptStyle.mono(13, weight: .semibold))
                    .foregroundStyle(ReceiptStyle.ink)

                    if index < rows.count - 1 {
                        ReceiptDashedDivider()
                    }
                }
            }
        }
    }

    private var selectedTypeTitle: String {
        TransactionType(rawValue: selectedTypeRawValue)?.displayName ?? "全部"
    }

    private var selectedCurrencyTitle: String {
        selectedCurrencyCode == LedgerCurrencyFilter.all ? "全部" : selectedCurrencyCode
    }

    private func menuPicker<Content: View>(
        title: String,
        selection: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ReceiptStyle.mono(10, weight: .bold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                    Text(selection)
                        .font(ReceiptStyle.mono(13, weight: .bold))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(ReceiptStyle.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func resetFilters() {
        searchText = ""
        selectedTypeRawValue = LedgerTypeFilter.all
        selectedCurrencyCode = LedgerCurrencyFilter.all
        selectedDateRange = .all
    }

    private func matchesSearch(_ transaction: TransactionRecord) -> Bool {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else {
            return true
        }

        let assetName = TransactionImpactService.appliedAsset(for: transaction, in: assets)?.name ?? ""
        let haystack = [
            transaction.note,
            transaction.categoryName,
            transaction.type.displayName,
            assetName,
            transaction.currencyCode ?? "CNY"
        ]
        return haystack.contains { value in
            value.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    private func matchesType(_ transaction: TransactionRecord) -> Bool {
        guard selectedTypeRawValue != LedgerTypeFilter.all else {
            return true
        }
        return transaction.typeRawValue == selectedTypeRawValue
    }

    private func matchesCurrency(_ transaction: TransactionRecord) -> Bool {
        guard selectedCurrencyCode != LedgerCurrencyFilter.all else {
            return true
        }
        return (transaction.currencyCode ?? "CNY") == selectedCurrencyCode
    }

    private func signedAmount(for transaction: TransactionRecord) -> Double {
        switch transaction.type {
        case .income, .investmentSell, .liabilityCreate:
            return transaction.amount
        case .expense, .investmentBuy, .liabilityRepayment:
            return -transaction.amount
        case .assetValueAdjustment:
            return transaction.amount
        case .transfer:
            return 0
        }
    }

    private func money(_ value: Double, currencyCode: String?, digits: Int = 0) -> String {
        CurrencyFormatterService.money(
            value,
            currencyCode: currencyCode ?? "CNY",
            minimumFractionDigits: digits,
            maximumFractionDigits: digits
        )
    }

    private func assetLabel(for transaction: TransactionRecord) -> String {
        guard transaction.linkedAssetID != nil else {
            return "NO ASSET"
        }

        return TransactionImpactService.appliedAsset(for: transaction, in: assets)?.name ?? "ASSET MISSING"
    }

    private func deleteTransaction(id: UUID) {
        guard let transaction = transactions.first(where: { $0.id == id }) else {
            return
        }

        statusMessage = nil
        let isMissingLinkedAsset = transaction.linkedAssetID != nil &&
            TransactionImpactService.appliedAsset(for: transaction, in: assets) == nil

        if let asset = TransactionImpactService.appliedAsset(for: transaction, in: assets) {
            TransactionImpactService.reverse(transaction, from: asset)
        }

        modelContext.delete(transaction)

        do {
            try modelContext.save()
            statusMessage = isMissingLinkedAsset ? "关联资产已不存在，仅删除交易记录" : "交易记录已删除"
        } catch {
            modelContext.rollback()
            statusMessage = "删除失败，请稍后重试"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private enum LedgerTypeFilter {
    static let all = "all"
}

private enum LedgerCurrencyFilter {
    static let all = "all"
}

private enum LedgerDateRangeFilter: String, CaseIterable {
    case all
    case today
    case month
    case year

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .today:
            return "今天"
        case .month:
            return "本月"
        case .year:
            return "今年"
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .month:
            return calendar.isDate(date, equalTo: .now, toGranularity: .month) &&
                calendar.isDate(date, equalTo: .now, toGranularity: .year)
        case .year:
            return calendar.isDate(date, equalTo: .now, toGranularity: .year)
        }
    }
}

private struct LedgerCurrencySummary: Identifiable {
    var currencyCode: String
    var income: Double
    var expense: Double
    var net: Double

    var id: String { currencyCode }
}

private struct PendingDeletion: Identifiable {
    let id: UUID
}
