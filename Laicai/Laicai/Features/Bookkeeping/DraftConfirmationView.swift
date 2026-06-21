import SwiftUI
import SwiftData

struct DraftConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let draft: DraftEntry
    @State private var amountText: String
    @State private var selectedType: TransactionType
    @State private var note: String
    @State private var categoryName: String

    init(draft: DraftEntry) {
        self.draft = draft
        _amountText = State(initialValue: DraftConfirmationView.formattedAmount(draft.amount))
        _selectedType = State(initialValue: draft.suggestedType)
        _note = State(initialValue: draft.note)
        _categoryName = State(initialValue: DraftConfirmationView.defaultCategoryName(for: draft.suggestedType))
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ""))
    }

    var body: some View {
        Form {
            Section("确认信息") {
                TextField("金额", text: $amountText)
                    .keyboardType(.decimalPad)

                Picker("类型", selection: $selectedType) {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Text(type.displayName)
                            .tag(type)
                    }
                }

                TextField("分类", text: $categoryName)
                TextField("备注", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("原始识别") {
                Text(draft.originalText)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("确认入账") {
                    guard let parsedAmount else {
                        return
                    }

                    let record = DraftConfirmationService.confirm(
                        draft,
                        type: selectedType,
                        amount: parsedAmount,
                        categoryName: categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                        note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    modelContext.insert(record)
                    modelContext.delete(draft)
                    try? modelContext.save()
                    dismiss()
                }
                .disabled(parsedAmount == nil || categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("确认草稿")
    }

    private static func formattedAmount(_ amount: Double) -> String {
        if amount.rounded() == amount {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }

    private static func defaultCategoryName(for type: TransactionType) -> String {
        switch type {
        case .income:
            return "收入"
        case .expense:
            return "日常支出"
        case .transfer:
            return "账户转账"
        case .investmentBuy:
            return "投资买入"
        case .investmentSell:
            return "投资卖出"
        case .assetValueAdjustment:
            return "资产调整"
        case .liabilityCreate:
            return "新增负债"
        case .liabilityRepayment:
            return "负债还款"
        }
    }
}
