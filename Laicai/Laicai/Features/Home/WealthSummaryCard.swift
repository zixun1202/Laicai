import SwiftUI

struct WealthSummaryCard: View {
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let netWorth: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("总资产（CNY）")
                .font(.headline)
            Text("¥\(NSDecimalNumber(decimal: netWorth).stringValue)")
                .font(.largeTitle.bold())
            HStack(spacing: 16) {
                Text("资产 ¥\(NSDecimalNumber(decimal: totalAssets).stringValue)")
                Text("负债 ¥\(NSDecimalNumber(decimal: totalLiabilities).stringValue)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack {
                SummaryChip(title: "现金", tint: .gray)
                SummaryChip(title: "投资", tint: .yellow)
                SummaryChip(title: "固产", tint: .green)
                SummaryChip(title: "负债", tint: .red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct SummaryChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
