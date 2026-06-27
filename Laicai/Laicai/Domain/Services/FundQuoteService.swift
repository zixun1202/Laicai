import Foundation

enum FundMarketRegion: String, Codable, CaseIterable {
    case china
    case overseas

    var displayName: String {
        switch self {
        case .china:
            return "国内"
        case .overseas:
            return "海外"
        }
    }

    var receiptCode: String {
        switch self {
        case .china:
            return "CN"
        case .overseas:
            return "GLOBAL"
        }
    }
}

struct FundQuotePoint: Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var value: Double

    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}

struct FundQuote: Identifiable, Equatable {
    var id: String { "\(market.rawValue)-\(symbol)" }
    var symbol: String
    var name: String
    var market: FundMarketRegion
    var latestValue: Double
    var changePercent: Double?
    var updatedAt: Date?
    var currencyCode: String
    var source: String
    var points: [FundQuotePoint]

    var trendPercent: Double? {
        guard let first = points.first?.value,
              let last = points.last?.value,
              first != 0 else {
            return nil
        }
        return (last - first) / first * 100
    }
}

enum FundQuoteError: LocalizedError {
    case missingSymbol
    case invalidResponse
    case remoteUnavailable

    var errorDescription: String? {
        switch self {
        case .missingSymbol:
            return "未填写行情代码"
        case .invalidResponse:
            return "行情返回格式无法识别"
        case .remoteUnavailable:
            return "行情服务暂不可用"
        }
    }
}

protocol FundQuoteFetching {
    func fetchQuote(symbol: String, market: FundMarketRegion) async throws -> FundQuote
}

struct FundQuoteService: FundQuoteFetching {
    var session: URLSession = .shared
    var akShareEndpoint: URL?

    init(session: URLSession = .shared, akShareEndpoint: URL? = nil) {
        self.session = session
        self.akShareEndpoint = akShareEndpoint
    }

    func fetchQuote(symbol: String, market: FundMarketRegion) async throws -> FundQuote {
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedSymbol.isEmpty else {
            throw FundQuoteError.missingSymbol
        }

        switch market {
        case .china:
            if let akShareEndpoint,
               let quote = try? await fetchAkShareQuote(symbol: normalizedSymbol, endpoint: akShareEndpoint) {
                return quote
            }
            return try await fetchChinaFundQuote(symbol: normalizedSymbol)
        case .overseas:
            return try await fetchOverseasQuote(symbol: normalizedSymbol)
        }
    }

    private func fetchAkShareQuote(symbol: String, endpoint: URL) async throws -> FundQuote {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "symbol", value: symbol))
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw FundQuoteError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard isSuccess(response) else {
            throw FundQuoteError.remoteUnavailable
        }
        return try FundQuoteParser.parseAkShareProxy(data, symbol: symbol)
    }

    private func fetchChinaFundQuote(symbol: String) async throws -> FundQuote {
        guard let valueURL = URL(string: "https://fundgz.1234567.com.cn/js/\(symbol).js?rt=\(Int(Date().timeIntervalSince1970 * 1000))"),
              let trendURL = URL(string: "https://fund.eastmoney.com/pingzhongdata/\(symbol).js?v=\(Int(Date().timeIntervalSince1970))") else {
            throw FundQuoteError.invalidResponse
        }

        async let valueResult = session.data(from: valueURL)
        async let trendResult = session.data(from: trendURL)
        let ((valueData, valueResponse), (trendData, trendResponse)) = try await (valueResult, trendResult)

        guard isSuccess(valueResponse), isSuccess(trendResponse) else {
            throw FundQuoteError.remoteUnavailable
        }

        return try FundQuoteParser.parseChinaFund(
            valueData: valueData,
            trendData: trendData,
            symbol: symbol
        )
    }

    private func fetchOverseasQuote(symbol: String) async throws -> FundQuote {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?range=1mo&interval=1d") else {
            throw FundQuoteError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard isSuccess(response) else {
            throw FundQuoteError.remoteUnavailable
        }
        return try FundQuoteParser.parseYahooChart(data, symbol: symbol)
    }

    private func isSuccess(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else {
            return true
        }
        return (200..<300).contains(httpResponse.statusCode)
    }
}

enum FundQuoteParser {
    static func parseAkShareProxy(_ data: Data, symbol: String) throws -> FundQuote {
        let payload = try JSONDecoder().decode(AkShareProxyPayload.self, from: data)
        let points = payload.points.map {
            FundQuotePoint(date: Date(timeIntervalSince1970: $0.timestamp / 1000), value: $0.value)
        }
        return FundQuote(
            symbol: payload.symbol ?? symbol,
            name: payload.name ?? symbol,
            market: .china,
            latestValue: payload.latestValue,
            changePercent: payload.changePercent,
            updatedAt: payload.updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            currencyCode: payload.currencyCode ?? "CNY",
            source: "AkShare",
            points: points
        )
    }

    static func parseChinaFund(valueData: Data, trendData: Data, symbol: String) throws -> FundQuote {
        let valueText = String(decoding: valueData, as: UTF8.self)
        let trendText = String(decoding: trendData, as: UTF8.self)
        let valuePayload = try parseChinaFundValue(valueText)
        let points = parseEastMoneyTrend(trendText)
        guard let latestValue = Double(valuePayload.estimatedValue ?? valuePayload.netValue) else {
            throw FundQuoteError.invalidResponse
        }

        return FundQuote(
            symbol: valuePayload.fundCode,
            name: valuePayload.name,
            market: .china,
            latestValue: latestValue,
            changePercent: Double(valuePayload.estimatedChangePercent),
            updatedAt: ChinaFundDateFormatter.parse(valuePayload.estimatedTime),
            currencyCode: "CNY",
            source: "AkShare fallback",
            points: points.isEmpty ? [FundQuotePoint(date: .now, value: latestValue)] : Array(points.suffix(30))
        )
    }

    static func parseYahooChart(_ data: Data, symbol: String) throws -> FundQuote {
        let payload = try JSONDecoder().decode(YahooChartPayload.self, from: data)
        guard let result = payload.chart.result?.first else {
            throw FundQuoteError.invalidResponse
        }

        let closes = result.indicators.quote.first?.close ?? []
        let timestamps = result.timestamp
        let points = zip(timestamps, closes).compactMap { timestamp, value -> FundQuotePoint? in
            guard let value else { return nil }
            return FundQuotePoint(date: Date(timeIntervalSince1970: TimeInterval(timestamp)), value: value)
        }
        guard let latestValue = points.last?.value else {
            throw FundQuoteError.invalidResponse
        }

        let previousClose = result.meta.previousClose ?? points.dropLast().last?.value
        let changePercent = previousClose.flatMap { previousClose -> Double? in
            guard previousClose != 0 else { return nil }
            return (latestValue - previousClose) / previousClose * 100
        }

        return FundQuote(
            symbol: result.meta.symbol ?? symbol,
            name: result.meta.shortName ?? result.meta.longName ?? result.meta.symbol ?? symbol,
            market: .overseas,
            latestValue: latestValue,
            changePercent: changePercent,
            updatedAt: result.meta.regularMarketTime.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            currencyCode: result.meta.currency ?? "USD",
            source: "Yahoo Finance",
            points: points
        )
    }

    private static func parseChinaFundValue(_ text: String) throws -> ChinaFundValuePayload {
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            throw FundQuoteError.invalidResponse
        }
        let jsonText = String(text[startIndex...endIndex])
        let payload = try JSONDecoder().decode(ChinaFundValuePayload.self, from: Data(jsonText.utf8))
        return payload
    }

    private static func parseEastMoneyTrend(_ text: String) -> [FundQuotePoint] {
        guard let range = text.range(of: #"var Data_netWorthTrend = \[(.*?)\];"#, options: .regularExpression) else {
            return []
        }

        let matchedText = String(text[range])
        guard let arrayStart = matchedText.firstIndex(of: "["),
              let arrayEnd = matchedText.lastIndex(of: "]") else {
            return []
        }

        let arrayText = String(matchedText[arrayStart...arrayEnd])
        guard let data = arrayText.data(using: .utf8),
              let rawItems = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return rawItems.compactMap { item in
            guard let timestamp = item["x"] as? Double,
                  let value = item["y"] as? Double else {
                return nil
            }
            return FundQuotePoint(date: Date(timeIntervalSince1970: timestamp / 1000), value: value)
        }
    }
}

private struct AkShareProxyPayload: Decodable {
    struct Point: Decodable {
        var timestamp: Double
        var value: Double
    }

    var symbol: String?
    var name: String?
    var latestValue: Double
    var changePercent: Double?
    var updatedAt: Double?
    var currencyCode: String?
    var points: [Point]
}

private struct ChinaFundValuePayload: Decodable {
    var fundCode: String
    var name: String
    var netValue: String
    var estimatedValue: String?
    var estimatedChangePercent: String
    var estimatedTime: String

    enum CodingKeys: String, CodingKey {
        case fundCode = "fundcode"
        case name
        case netValue = "dwjz"
        case estimatedValue = "gsz"
        case estimatedChangePercent = "gszzl"
        case estimatedTime = "gztime"
    }
}

private enum ChinaFundDateFormatter {
    static func parse(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)
    }
}

private struct YahooChartPayload: Decodable {
    var chart: Chart

    struct Chart: Decodable {
        var result: [Result]?
    }

    struct Result: Decodable {
        var meta: Meta
        var timestamp: [Int]
        var indicators: Indicators
    }

    struct Meta: Decodable {
        var currency: String?
        var symbol: String?
        var shortName: String?
        var longName: String?
        var regularMarketTime: Int?
        var previousClose: Double?
    }

    struct Indicators: Decodable {
        var quote: [Quote]
    }

    struct Quote: Decodable {
        var close: [Double?]
    }
}
