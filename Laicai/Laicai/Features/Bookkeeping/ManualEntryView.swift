import SwiftUI
import SwiftData

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var amount = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("金额", text: $amount)
                    .keyboardType(.decimalPad)
                TextField("备注", text: $note)
            }
            .navigationTitle("手工录入")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let value = Double(amount) ?? 0
                        let record = TransactionRecord(
                            type: .expense,
                            amount: value,
                            date: .now,
                            categoryName: "手工记账",
                            note: note
                        )
                        modelContext.insert(record)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
