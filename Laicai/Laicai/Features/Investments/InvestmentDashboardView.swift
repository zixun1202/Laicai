import SwiftUI
import SwiftData

struct InvestmentDashboardView: View {
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query private var profiles: [UserProfile]
    @State private var quotes: [UUID: FundQuote] = [:]
    @State private var quoteErrors: [UUID: String] = [:]
    @State private var isRefreshingQuotes = false
    @State private var lastQuoteRefresh: Date?

    private let quoteService = FundQuoteService()

    private var summary: InvestmentSummary {
        PortfolioSummaryService.investmentSummary(for: assets)
    }

    private var currencyCode: String {
        profiles.first?.defaultCurrency ?? "CNY"
    }

    private var quotedAssets: [Asset] {
        assets
            .filter { $0.categoryName == "投资资产" }
            .filter { !($0.quoteSymbol ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var quoteRefreshKey: String {
        quotedAssets
            .map { "\($0.id.uuidString):\($0.quoteSymbol ?? ""):\($0.quoteMarketRawValue ?? "")" }
            .joined(separator: "|")
    }

    private var successfulQuoteCount: Int {
        quotedAssets.filter { quotes[$0.id] != nil }.count
    }

    var body: some View {
        ReceiptPaper(tornEdges: false) {
            VStack(spacing: 16) {
                TicketPageHeader(title: "投资看板", subtitle: "WATCH LIST", systemImage: "chart.line.uptrend.xyaxis")

                VStack(spacing: 7) {
                    ReceiptDashedDivider()
                    ReceiptInfoRow(label: "TOTAL", value: money(summary.totalValue))
                    ReceiptInfoRow(label: "HOLDINGS", value: String(format: "%02d", summary.holdingsCount))
                    ReceiptInfoRow(label: "QUOTES", value: String(format: "%02d/%02d", successfulQuoteCount, quotedAssets.count))
                    ReceiptInfoRow(label: "STATUS", value: quoteStatus)
                    ReceiptDashedDivider()
                }

                localHoldingsSection
                quoteWatchListSection
            }
        }
        .task(id: quoteRefreshKey) {
            await refreshQuotesIfNeeded()
        }
    }

    @ViewBuilder
    private var localHoldingsSection: some View {
        if summary.breakdowns.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("暂无投资资产")
                    .font(ReceiptStyle.mono(16, weight: .bold))
                Text("· 在资产页新增基金、股票或理财后，这里会自动汇总")
                    .font(ReceiptStyle.mono(13, weight: .semibold))
                    .foregroundStyle(ReceiptStyle.fadedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 10) {
                ReceiptSectionLabel(title: "本地持仓")
                ForEach(summary.breakdowns, id: \.name) { item in
                    ReceiptInfoRow(label: item.name, value: money(item.value))
                }
            }
        }
    }

    private var quoteWatchListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReceiptSectionLabel(title: "基金走势")

            if quotedAssets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("还没有绑定行情代码")
                        .font(ReceiptStyle.mono(15, weight: .bold))
                    Text("· 在投资资产里填写基金/ETF 代码后，这里会显示国内外走势")
                        .font(ReceiptStyle.mono(12, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await refreshQuotes()
                        }
                    } label: {
                        Label(isRefreshingQuotes ? "刷新中" : "刷新走势", systemImage: "arrow.clockwise")
                            .font(ReceiptStyle.mono(12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(ReceiptStyle.paper)
                            .background(ReceiptStyle.ink, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshingQuotes)
                    .opacity(isRefreshingQuotes ? 0.62 : 1)
                }

                if let lastQuoteRefresh {
                    Text("· 更新时间 \(Self.shortDateFormatter.string(from: lastQuoteRefresh))，行情仅展示，不自动改资产价值")
                        .font(ReceiptStyle.mono(11, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                } else {
                    Text("· 国内优先 AkShare 代理，未配置时使用公开估值接口；海外使用公开行情接口")
                        .font(ReceiptStyle.mono(11, weight: .semibold))
                        .foregroundStyle(ReceiptStyle.fadedInk)
                }

                quoteGroup(title: "国内基金", market: .china)
                quoteGroup(title: "海外基金 / ETF", market: .overseas)
            }
        }
        .foregroundStyle(ReceiptStyle.ink)
    }

    private func quoteGroup(title: String, market: FundMarketRegion) -> some View {
        let items = quotedAssets.filter { $0.quoteMarket == market }
        return VStack(spacing: 12) {
            if !items.isEmpty {
                ReceiptSectionLabel(title: title)
                ForEach(Array(items.enumerated()), id: \.element.id) { index, asset in
                    VStack(spacing: 12) {
                        FundQuoteRow(
                            index: index + 1,
                            asset: asset,
                            quote: quotes[asset.id],
                            errorMessage: quoteErrors[asset.id]
                        )

                        if index < items.count - 1 {
                            ReceiptDashedDivider()
                        }
                    }
                }
            }
        }
    }

    private var quoteStatus: String {
        if quotedAssets.isEmpty {
            return "NO CODE"
        }
        if isRefreshingQuotes {
            return "SYNCING"
        }
        if successfulQuoteCount == quotedAssets.count {
            return "UPDATED"
        }
        if successfulQuoteCount > 0 {
            return "PARTIAL"
        }
        return quoteErrors.isEmpty ? "READY" : "FAILED"
    }

    @MainActor
    private func refreshQuotesIfNeeded() async {
        guard !quotedAssets.isEmpty else {
            quotes = [:]
            quoteErrors = [:]
            return
        }
        guard quotes.isEmpty else {
            return
        }
        await refreshQuotes()
    }

    @MainActor
    private func refreshQuotes() async {
        guard !isRefreshingQuotes else {
            return
        }

        isRefreshingQuotes = true
        defer {
            isRefreshingQuotes = false
        }

        var nextQuotes = quotes
        var nextErrors: [UUID: String] = [:]

        for asset in quotedAssets {
            let symbol = asset.quoteSymbol ?? ""
            do {
                let quote = try await quoteService.fetchQuote(symbol: symbol, market: asset.quoteMarket)
                nextQuotes[asset.id] = quote
            } catch {
                nextErrors[asset.id] = error.localizedDescription
            }
        }

        quotes = nextQuotes
        quoteErrors = nextErrors
        lastQuoteRefresh = .now
    }

    private func money(_ value: Decimal) -> String {
        CurrencyFormatterService.money(value, currencyCode: currencyCode)
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private struct FundQuoteRow: View {
    let index: Int
    let asset: Asset
    let quote: FundQuote?
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Text(String(format: "%02d", index))
                    .frame(width: 32, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(asset.name)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(asset.quoteSymbol ?? "--")
                            .foregroundStyle(ReceiptStyle.fadedInk)
                    }

                    if let quote {
                        Text("· \(quote.market.receiptCode) \(quote.source) / \(quote.currencyCode)")
                            .font(ReceiptStyle.mono(11, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.fadedInk)
                    } else if let errorMessage {
                        Text("· \(errorMessage)")
                            .font(ReceiptStyle.mono(11, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.fadedInk)
                    } else {
                        Text("· 等待刷新行情")
                            .font(ReceiptStyle.mono(11, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.fadedInk)
                    }
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
                    .frame(width: 96, height: 30)
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
            return errorMessage == nil ? "暂无行情快照" : "保留本地资产价值"
        }
        let updatedAt = quote.updatedAt.map { Self.dateFormatter.string(from: $0) } ?? "时间未知"
        let trend = quote.trendPercent.map { " / 30D \(Self.percent($0))" } ?? ""
        return "最新 \(updatedAt)\(trend)"
    }

    private static func valueText(_ quote: FundQuote) -> String {
        NumberFormatter.quoteValue.string(from: NSNumber(value: quote.latestValue)) ?? String(format: "%.4f", quote.latestValue)
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

struct SparklineView: View {
    let points: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard points.count > 1 else {
                    let y = proxy.size.height / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    return
                }

                let minValue = points.min() ?? 0
                let maxValue = points.max() ?? 1
                let span = max(maxValue - minValue, 0.0001)
                let stepX = proxy.size.width / CGFloat(points.count - 1)

                for index in points.indices {
                    let normalized = (points[index] - minValue) / span
                    let point = CGPoint(
                        x: CGFloat(index) * stepX,
                        y: proxy.size.height - CGFloat(normalized) * proxy.size.height
                    )
                    if index == points.startIndex {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: ReceiptStyle.outlineWidth, lineCap: .round, lineJoin: .round))
        }
        .padding(6)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.32), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

private extension NumberFormatter {
    static let quoteValue: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter
    }()
}
