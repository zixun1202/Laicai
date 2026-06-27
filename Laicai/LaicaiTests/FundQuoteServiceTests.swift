import XCTest
@testable import Laicai

final class FundQuoteServiceTests: XCTestCase {
    func testParseChinaFundJsonpAndTrend() throws {
        let valueText = """
        jsonpgz({"fundcode":"161725","name":"招商中证白酒指数(LOF)A","jzrq":"2026-06-25","dwjz":"0.5162","gsz":"0.5002","gszzl":"-3.10","gztime":"2026-06-26 15:00"});
        """
        let trendText = """
        var Data_netWorthTrend = [{"x":1719273600000,"y":0.5100,"equityReturn":0,"unitMoney":""},{"x":1719360000000,"y":0.5162,"equityReturn":1.2157,"unitMoney":""}];
        """

        let quote = try FundQuoteParser.parseChinaFund(
            valueData: Data(valueText.utf8),
            trendData: Data(trendText.utf8),
            symbol: "161725"
        )

        XCTAssertEqual(quote.symbol, "161725")
        XCTAssertEqual(quote.name, "招商中证白酒指数(LOF)A")
        XCTAssertEqual(quote.market, .china)
        XCTAssertEqual(quote.latestValue, 0.5002)
        XCTAssertEqual(quote.changePercent, -3.10)
        XCTAssertEqual(quote.currencyCode, "CNY")
        XCTAssertEqual(quote.points.map(\.value), [0.5100, 0.5162])
    }

    func testParseYahooChartUsesClosePrices() throws {
        let chartText = """
        {
          "chart": {
            "result": [
              {
                "meta": {
                  "currency": "USD",
                  "symbol": "VOO",
                  "shortName": "Vanguard S&P 500 ETF",
                  "regularMarketTime": 1719360000,
                  "previousClose": 500
                },
                "timestamp": [1719187200, 1719273600, 1719360000],
                "indicators": {
                  "quote": [
                    {
                      "close": [498.5, null, 505.0]
                    }
                  ]
                }
              }
            ]
          }
        }
        """

        let quote = try FundQuoteParser.parseYahooChart(Data(chartText.utf8), symbol: "VOO")

        XCTAssertEqual(quote.symbol, "VOO")
        XCTAssertEqual(quote.name, "Vanguard S&P 500 ETF")
        XCTAssertEqual(quote.market, .overseas)
        XCTAssertEqual(quote.latestValue, 505.0)
        XCTAssertEqual(quote.changePercent, 1.0)
        XCTAssertEqual(quote.points.map(\.value), [498.5, 505.0])
    }

    func testParseAkShareProxyPayload() throws {
        let proxyText = """
        {
          "symbol": "000001",
          "name": "华夏成长混合",
          "latestValue": 1.2345,
          "changePercent": 0.82,
          "updatedAt": 1719360000000,
          "currencyCode": "CNY",
          "points": [
            { "timestamp": 1719273600000, "value": 1.22 },
            { "timestamp": 1719360000000, "value": 1.2345 }
          ]
        }
        """

        let quote = try FundQuoteParser.parseAkShareProxy(Data(proxyText.utf8), symbol: "000001")

        XCTAssertEqual(quote.source, "AkShare")
        XCTAssertEqual(quote.symbol, "000001")
        XCTAssertEqual(quote.latestValue, 1.2345)
        XCTAssertEqual(quote.trendPercent.map { round($0 * 100) / 100 }, 1.19)
    }
}
