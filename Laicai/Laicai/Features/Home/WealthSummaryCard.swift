import SwiftUI

struct WealthSummaryCard: View {
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let netWorth: Decimal
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReceiptInfoRow(label: "NET WORTH", value: money(netWorth))

            VStack(spacing: 8) {
                summaryLine(title: "资产", value: totalAssets, marker: "CASH")
                summaryLine(title: "负债", value: totalLiabilities, marker: "DEBT")
            }

            HStack(spacing: 8) {
                SummaryChip(title: "现金")
                SummaryChip(title: "投资")
                SummaryChip(title: "固产")
                SummaryChip(title: "负债")
            }
        }
        .padding(.vertical, 4)
    }

    private func summaryLine(title: String, value: Decimal, marker: String) -> some View {
        HStack {
            Text("· \(title)")
            Spacer()
            Text(marker)
                .foregroundStyle(ReceiptStyle.fadedInk)
            Text(money(value))
        }
        .font(ReceiptStyle.mono(13, weight: .semibold))
        .foregroundStyle(ReceiptStyle.ink)
    }

    private func money(_ value: Decimal) -> String {
        CurrencyFormatterService.money(value, currencyCode: currencyCode)
    }
}

private struct SummaryChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(ReceiptStyle.mono(11, weight: .bold))
            .foregroundStyle(ReceiptStyle.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(ReceiptStyle.ink.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            )
    }
}
