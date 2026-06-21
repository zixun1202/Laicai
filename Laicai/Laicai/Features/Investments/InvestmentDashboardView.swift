import SwiftUI

struct InvestmentDashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投资看板")
                .font(.headline)
            Text("展示投资总额、分类分布与当前价值概览")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}
