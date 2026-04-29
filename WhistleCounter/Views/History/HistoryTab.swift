import SwiftUI

struct HistoryTab: View {
    @Environment(HistoryStore.self) private var store

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Sessions you count will appear here.")
                    )
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .disabled(store.records.isEmpty)
                }
            }
            .confirmationDialog(
                "Clear all history?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear all", role: .destructive) {
                    store.clearAll()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private var historyList: some View {
        List {
            ForEach(store.records) { record in
                HistoryRow(record: record)
            }
            .onDelete { offsets in
                store.delete(at: offsets)
            }
        }
    }
}

private struct HistoryRow: View {
    let record: SessionRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(record.whistleCount)")
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private var title: String {
        record.recipeName ?? "Session"
    }

    private var subtitle: String {
        "\(formattedDate) · \(formattedDuration)"
    }

    private var formattedDate: String {
        record.startedAt.formatted(
            .relative(presentation: .named)
        )
    }

    private var formattedDuration: String {
        let minutes = Int(record.duration) / 60
        let seconds = Int(record.duration) % 60
        if minutes == 0 { return "\(seconds)s" }
        return "\(minutes)m \(seconds)s"
    }
}

#Preview("Empty") {
    HistoryTab()
        .environment(HistoryStore(fileURL: URL(filePath: "/tmp/history-preview-empty.json")))
}
