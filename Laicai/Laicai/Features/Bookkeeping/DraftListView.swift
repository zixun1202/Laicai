import SwiftUI
import SwiftData

struct DraftListView: View {
    @Query(sort: \DraftEntry.createdAt, order: .reverse) private var drafts: [DraftEntry]

    var body: some View {
        List(drafts, id: \.id) { draft in
            Text(draft.note)
        }
        .navigationTitle("草稿")
    }
}
