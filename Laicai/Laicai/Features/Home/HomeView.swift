import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query private var profiles: [UserProfile]
    @State private var fundQuotes: [UUID: FundQuote] = [:]
    @State private var fundQuoteErrors: [UUID: String] = [:]
    @State private var isRefreshingFundQuotes = false
    @State private var lastFundQuoteRefresh: Date?
    private let quoteService = FundQuoteService()

    private var summary: NetWorthSummary {
        PortfolioSummaryService.netWorthSummary(for: assets)
    }

    private var currencyCode: String {
        profiles.first?.defaultCurrency ?? "CNY"
    }

    private var todayTransactions: [TransactionRecord] {
        transactions.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var receiptItems: [TransactionRecord] {
        Array(todayTransactions.prefix(4))
    }

    private var todayNetFlow: Double {
        todayTransactions.reduce(0) { total, transaction in
            total + signedAmount(for: transaction)
        }
    }

    private var quotedFundAssets: [Asset] {
        assets
            .filter { $0.categoryName == "投资资产" }
            .filter { !($0.quoteSymbol ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var fundQuoteRefreshKey: String {
        quotedFundAssets
            .map { "\($0.id.uuidString):\($0.quoteSymbol ?? ""):\($0.quoteMarketRawValue ?? "")" }
            .joined(separator: "|")
    }

    private var successfulFundQuoteCount: Int {
        quotedFundAssets.filter { fundQuotes[$0.id] != nil }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ReceiptPaper(tornEdges: false) {
                        VStack(spacing: 16) {
                            TicketPageHeader(title: "今日小票", subtitle: "FINANCE DASH", systemImage: "bell")
                            ticketMeta
                            assetLedgerButton
                            fundTrendSection
                            assetDistribution
                            NavigationLink {
                                TransactionHistoryView()
                            } label: {
                                activityPanel
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    InvestmentDashboardView()
                        .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 150)
            }
            .background(ReceiptStyle.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task(id: fundQuoteRefreshKey) {
                await refreshFundQuotesIfNeeded()
            }
        }
    }

    private var ticketMeta: some View {
        VStack(spacing: 7) {
            ReceiptDashedDivider()
            ReceiptInfoRow(label: "DATE", value: Self.shortDateFormatter.string(from: .now))
            ReceiptInfoRow(label: "CATEGORIES", value: String(format: "%02d", allocationRows.count))
            ReceiptInfoRow(label: "ASSET ITEMS", value: String(format: "%02d", assets.count))
            ReceiptInfoRow(label: "ASSETS", value: money(summary.totalAssets))
            ReceiptInfoRow(label: "LIABILITIES", value: money(summary.totalLiabilities))
            ReceiptInfoRow(label: "NET WORTH", value: money(summary.netWorth))
            ReceiptInfoRow(label: "TODAY FLOW", value: flowText)
            ReceiptInfoRow(label: "FUND QUOTES", value: fundQuoteStatus)
            ReceiptDashedDivider()
        }
    }

    private var assetLedgerButton: some View {
        NavigationLink {
            AssetsView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tray.full")
                Text("查看资产账本")
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(ReceiptStyle.mono(13, weight: .bold))
            .foregroundStyle(ReceiptStyle.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(ReceiptStyle.ink, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var assetDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReceiptSectionLabel(title: "资产分布")

            VStack(spacing: 14) {
                ForEach(Array(allocationRows.enumerated()), id: \.element.title) { index, row in
                    NavigationLink {
                        AssetsView()
                    } label: {
                        VStack(spacing: 12) {
                            receiptListRow(
                                index: index + 1,
                                title: row.title,
                                subtitle: row.subtitle,
                                value: row.value,
                                valueTint: row.tint
                            )

                            if index < allocationRows.count - 1 {
                                ReceiptDashedDivider()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var fundTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReceiptSectionLabel(title: "实时基金趋势")

            if quotedFundAssets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("还没有绑定行情代码")
                        .font(ReceiptStyle.mono(14, weight: .bold))
                    Text("· 在资产页给投资资产填写基金/ETF 代码后，首页会自动刷新红绿趋势")
                        .font(ReceiptStyle.mono(12, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    Task {
                        await refreshFundQuotes()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(isRefreshingFundQuotes ? "刷新中" : "刷新实时基金数据")
                    }
                    .font(ReceiptStyle.mono(12, weight: .bold))
                    .foregroundStyle(ReceiptStyle.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(ReceiptStyle.ink, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshingFundQuotes)
                .opacity(isRefreshingFundQuotes ? 0.62 : 1)

                if let lastFundQuoteRefresh {
                    Text("· 更新时间 \(Self.quoteDateFormatter.string(from: lastFundQuoteRefresh))")
                        .font(ReceiptStyle.mono(11, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                } else {
                    Text("· 打开首页时自动调用行情接口，红涨绿跌")
                        .font(ReceiptStyle.mono(11, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                }

                VStack(spacing: 14) {
                    ForEach(Array(quotedFundAssets.prefix(3).enumerated()), id: \.element.id) { index, asset in
                        VStack(spacing: 12) {
                            HomeFundTrendRow(
                                index: index + 1,
                                asset: asset,
                                quote: fundQuotes[asset.id],
                                errorMessage: fundQuoteErrors[asset.id]
                            )

                            if index < min(quotedFundAssets.count, 3) - 1 {
                                ReceiptDashedDivider()
                            }
                        }
                    }
                }
            }
        }
        .foregroundStyle(ReceiptStyle.ink)
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReceiptSectionLabel(title: "今日流水")

            if receiptItems.isEmpty {
                Text("还没有记账，点中间的记账入口开始。")
                    .font(ReceiptStyle.mono(13, weight: .semibold))
                    .foregroundStyle(ReceiptStyle.fadedInk)
            } else {
                VStack(spacing: 14) {
                    ForEach(Array(receiptItems.enumerated()), id: \.element.id) { index, transaction in
                        VStack(spacing: 12) {
                            receiptListRow(
                                index: index + 1,
                                title: transaction.note.isEmpty ? transaction.categoryName : transaction.note,
                                subtitle: transaction.type.displayName,
                                value: money(transaction.amount, currencyCode: transaction.currencyCode, digits: 2),
                                valueTint: transactionAmountTint(transaction)
                            )

                            if index < receiptItems.count - 1 {
                                ReceiptDashedDivider()
                            }
                        }
                    }
                }
            }

            ReceiptDashedDivider()
            ReceiptInfoRow(label: "UPDATED", value: "HOME LEDGER")
        }
        .foregroundStyle(ReceiptStyle.ink)
    }

    private func receiptListRow(index: Int, title: String, subtitle: String, value: String, valueTint: Color = ReceiptStyle.ink) -> some View {
        HStack(alignment: .top) {
            Text(String(format: "%02d", index))
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .fontWeight(.bold)
                Text("· \(subtitle)")
                    .foregroundStyle(ReceiptStyle.fadedInk)
            }

            Spacer()
            Text(value)
                .foregroundStyle(valueTint)
        }
        .font(ReceiptStyle.mono(13, weight: .semibold))
        .foregroundStyle(ReceiptStyle.ink)
    }

    private var allocationRows: [AllocationRowData] {
        [
            AllocationRowData(
                title: "现金与账户",
                subtitle: "现金账户",
                value: money(assetValue(categoryName: "现金与账户")),
                tint: ReceiptStyle.ink
            ),
            AllocationRowData(
                title: "投资资产",
                subtitle: "股票 · 基金 · ETF",
                value: money(assetValue(categoryName: "投资资产")),
                tint: ReceiptStyle.positive
            ),
            AllocationRowData(
                title: "固定资产",
                subtitle: "房产 · 车辆 · 收藏",
                value: money(assetValue(categoryName: "固定资产")),
                tint: ReceiptStyle.ink
            ),
            AllocationRowData(
                title: "负债",
                subtitle: "贷款 · 信用卡 · 借款",
                value: money(assetValue(categoryName: "负债")),
                tint: .red.opacity(0.72)
            )
        ]
    }

    private func assetValue(categoryName: String) -> Decimal {
        assets
            .filter { $0.categoryName == categoryName }
            .reduce(Decimal(0)) { total, asset in
                total + Decimal(asset.currentValue)
            }
    }

    private var flowText: String {
        let sign = todayNetFlow >= 0 ? "+" : "-"
        return "\(sign)\(money(abs(todayNetFlow), digits: 0))"
    }

    private var fundQuoteStatus: String {
        if quotedFundAssets.isEmpty {
            return "NO CODE"
        }
        if isRefreshingFundQuotes {
            return "SYNCING"
        }
        return String(format: "%02d/%02d", successfulFundQuoteCount, quotedFundAssets.count)
    }

    @MainActor
    private func refreshFundQuotesIfNeeded() async {
        guard !quotedFundAssets.isEmpty else {
            fundQuotes = [:]
            fundQuoteErrors = [:]
            lastFundQuoteRefresh = nil
            return
        }
        guard fundQuotes.isEmpty else {
            return
        }
        await refreshFundQuotes()
    }

    @MainActor
    private func refreshFundQuotes() async {
        guard !isRefreshingFundQuotes else {
            return
        }

        isRefreshingFundQuotes = true
        defer {
            isRefreshingFundQuotes = false
        }

        var nextQuotes = fundQuotes
        var nextErrors: [UUID: String] = [:]

        for asset in quotedFundAssets {
            let symbol = asset.quoteSymbol ?? ""
            do {
                nextQuotes[asset.id] = try await quoteService.fetchQuote(symbol: symbol, market: asset.quoteMarket)
            } catch {
                nextErrors[asset.id] = error.localizedDescription
            }
        }

        fundQuotes = nextQuotes
        fundQuoteErrors = nextErrors
        lastFundQuoteRefresh = .now
    }

    private func money(_ value: Decimal) -> String {
        CurrencyFormatterService.money(value, currencyCode: currencyCode)
    }

    private func money(_ value: Double, currencyCode: String? = nil, digits: Int = 0) -> String {
        CurrencyFormatterService.money(
            value,
            currencyCode: currencyCode ?? self.currencyCode,
            minimumFractionDigits: digits,
            maximumFractionDigits: digits
        )
    }

    private func signedAmount(for transaction: TransactionRecord) -> Double {
        switch transaction.type {
        case .income, .investmentSell, .assetValueAdjustment:
            return transaction.amount
        case .expense, .investmentBuy, .liabilityRepayment:
            return -transaction.amount
        case .transfer, .liabilityCreate:
            return 0
        }
    }

    private func transactionAmountTint(_ transaction: TransactionRecord) -> Color {
        signedAmount(for: transaction) >= 0 ? ReceiptStyle.positive : ReceiptStyle.ink
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let quoteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private struct AllocationRowData {
    let title: String
    let subtitle: String
    let value: String
    let tint: Color
}

private struct HomeFundTrendRow: View {
    let index: Int
    let asset: Asset
    let quote: FundQuote?
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Text(String(format: "%02d", index))
                    .frame(width: 34, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(asset.name)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(asset.quoteSymbol ?? "--")
                            .foregroundStyle(ReceiptStyle.fadedInk)
                    }

                    Text(statusText)
                        .font(ReceiptStyle.mono(11, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(quote.map { Self.valueText($0) } ?? "--")
                        .font(ReceiptStyle.mono(14, weight: .black))
                        .foregroundStyle(quoteTint)
                    Text(percentText)
                        .font(ReceiptStyle.mono(11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(quoteTint.opacity(0.16), in: Capsule())
                        .foregroundStyle(quoteTint)
                }
            }

            HStack(spacing: 10) {
                SparklineView(points: quote?.points.map(\.value) ?? [], tint: quoteTint)
                    .frame(width: 96, height: 28)
                Text(detailText)
                    .font(ReceiptStyle.mono(11, weight: .semibold))
                    .foregroundStyle(ReceiptStyle.fadedInk)
                    .lineLimit(2)
                Spacer()
            }
        }
        .font(ReceiptStyle.mono(13, weight: .semibold))
        .foregroundStyle(ReceiptStyle.ink)
    }

    private var quoteTint: Color {
        guard let quote else {
            return errorMessage == nil ? ReceiptStyle.fadedInk : Color(red: 0.74, green: 0.20, blue: 0.18)
        }
        let value = quote.changePercent ?? quote.trendPercent ?? 0
        if value > 0 {
            return Color(red: 0.78, green: 0.16, blue: 0.14)
        }
        if value < 0 {
            return Color(red: 0.10, green: 0.52, blue: 0.27)
        }
        return ReceiptStyle.fadedInk
    }

    private var statusText: String {
        if let quote {
            return "· \(quote.market.receiptCode) \(quote.source) / \(quote.currencyCode)"
        }
        if let errorMessage {
            return "· \(errorMessage)"
        }
        return "· 等待实时行情"
    }

    private var percentText: String {
        guard let quote else {
            return errorMessage == nil ? "READY" : "FAILED"
        }
        if let changePercent = quote.changePercent {
            return Self.percent(changePercent)
        }
        if let trendPercent = quote.trendPercent {
            return "30D \(Self.percent(trendPercent))"
        }
        return "UNCHANGED"
    }

    private var detailText: String {
        guard let quote else {
            return errorMessage == nil ? "打开首页后自动刷新" : "保留本地资产价值"
        }
        let updatedAt = quote.updatedAt.map { Self.dateFormatter.string(from: $0) } ?? "时间未知"
        let trend = quote.trendPercent.map { " / 30D \(Self.percent($0))" } ?? ""
        return "最新 \(updatedAt)\(trend)"
    }

    private static func valueText(_ quote: FundQuote) -> String {
        NumberFormatter.homeQuoteValue.string(from: NSNumber(value: quote.latestValue)) ?? String(format: "%.4f", quote.latestValue)
    }

    private static func percent(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "")\(String(format: "%.2f", value))%"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private extension NumberFormatter {
    static let homeQuoteValue: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter
    }()
}
