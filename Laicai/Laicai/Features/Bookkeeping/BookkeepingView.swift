import SwiftUI
import SwiftData

struct BookkeepingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DraftEntry.createdAt, order: .reverse) private var drafts: [DraftEntry]
    @State private var showingManualEntry = false

    var body: some View {
        NavigationStack {
            List {
                Section("录入") {
                    Button("手工记一笔") {
                        showingManualEntry = true
                    }
                    Button("语音录入") {
                        insertDraftIfPossible(
                            sourceType: "voice",
                            originalText: "买基金 1000"
                        )
                    }
                    Button("截图录入") {
                        insertDraftIfPossible(
                            sourceType: "screenshot",
                            originalText: "午饭 38"
                        )
                    }
                }

                Section("待确认草稿") {
                    if drafts.isEmpty {
                        Text("暂无草稿")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(drafts, id: \.id) { draft in
                            NavigationLink {
                                DraftConfirmationView(draft: draft)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(draft.note)
                                    Text("¥\(draft.amount, specifier: "%.2f")")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("记账")
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
        }
    }

    private func insertDraftIfPossible(sourceType: String, originalText: String) {
        guard let draft = DraftCreationService.createDraft(
            sourceType: sourceType,
            originalText: originalText
        ) else {
            return
        }

        modelContext.insert(draft)
        try? modelContext.save()
    }
}
