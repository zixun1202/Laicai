import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]

    private var summary: NetWorthSummary {
        NetWorthCalculator.calculate(assetValues: [250_000], liabilityValues: [80_000])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("财富总览")
                        .font(.title2.bold())

                    WealthSummaryCard(
                        totalAssets: summary.totalAssets,
                        totalLiabilities: summary.totalLiabilities,
                        netWorth: summary.netWorth
                    )

                    InvestmentDashboardView()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近活动")
                            .font(.headline)

                        if transactions.isEmpty {
                            Text("暂无记录")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(transactions.prefix(5), id: \.id) { transaction in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.note.isEmpty ? transaction.categoryName : transaction.note)
                                    Text("¥\(transaction.amount, specifier: "%.2f")")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("首页")
        }
    }
}
