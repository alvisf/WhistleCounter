import SwiftUI

/// Combined Counter + History tab — counter on top, recent sessions
/// below, styled like the Clock app's Timers tab.
struct CounterTab: View {
    @Environment(WhistleSession.self) private var session
    @Environment(HistoryStore.self) private var historyStore

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // -- Top half: counter + controls --
                VStack(spacing: 0) {
                    Spacer()
                    CounterView()
                    Spacer()
                    ControlsView()
                        .padding(.horizontal, 24)
                    Divider()
                        .padding(.top, 20)
                    SettingsView()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                Divider()

                // -- Bottom half: history list --
                if historyStore.records.isEmpty {
                    Spacer()
                    Text("Sessions will appear here")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(historyStore.records) { record in
                            HistoryRow(record: record)
                                .listRowBackground(Color.black)
                        }
                        .onDelete { offsets in
                            historyStore.delete(at: offsets)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(.black)
            .navigationTitle("Counter")
            .toolbar {
                if !historyStore.records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            showClearConfirmation = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog(
                "Clear all history?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear all", role: .destructive) {
                    historyStore.clearAll()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Target reached!", isPresented: targetReachedBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(session.count) whistles. Time to turn off the heat.")
            }
        }
    }

    private var targetReachedBinding: Binding<Bool> {
        Binding(
            get: { session.targetReached },
            set: { _ in session.dismissTargetAlert() }
        )
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let record: SessionRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.recipeName ?? "Session")
                    .font(.body)
                Text("\(formattedDate) · \(formattedDuration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(record.whistleCount)")
                .font(.title3)
                .monospacedDigit()
        }
    }

    private var formattedDate: String {
        record.startedAt.formatted(.relative(presentation: .named))
    }

    private var formattedDuration: String {
        let minutes = Int(record.duration) / 60
        let seconds = Int(record.duration) % 60
        if minutes == 0 { return "\(seconds)s" }
        return "\(minutes)m \(seconds)s"
    }
}

#Preview {
    CounterTab()
        .environment(WhistleSession())
        .environment(AlarmSoundStore())
        .environment(HistoryStore(fileURL: URL(filePath: "/tmp/history-preview.json")))
}
