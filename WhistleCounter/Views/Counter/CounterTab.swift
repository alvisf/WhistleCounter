import SwiftUI

/// Combined Counter + History tab — fully scrollable, with a "Recent"
/// section header separating the counter from session history.
struct CounterTab: View {
    @Environment(WhistleSession.self) private var session
    @Environment(HistoryStore.self) private var historyStore

    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                // -- Counter section --
                Section {
                    VStack(spacing: 0) {
                        CounterView()
                            .padding(.vertical, 20)
                        ControlsView()
                            .padding(.horizontal, 8)
                            .padding(.bottom, 24)
                        SettingsView()
                    }
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                // -- Recent section --
                Section {
                    if historyStore.records.isEmpty {
                        Text("Sessions will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                            .listRowBackground(Color.black)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(historyStore.records) { record in
                            HistoryRow(record: record, isEditing: isEditing) {
                                replayRecord(record)
                            }
                            .listRowBackground(Color.black)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        }
                        .onDelete { offsets in
                            historyStore.delete(at: offsets)
                        }
                    }
                } header: {
                    Text("Recents")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
            .background(.black)
            .scrollContentBackground(.hidden)
            .navigationTitle("Counter")
            .toolbar {
                if !historyStore.records.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                        }
                    }
                }
            }
            .alert("Target reached!", isPresented: targetReachedBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(session.count) whistles. Time to turn off the heat.")
            }
        }
    }

    private func replayRecord(_ record: SessionRecord) {
        session.reset()
        session.targetCount = record.whistleCount
        if let name = record.recipeName {
            session.activeRecipeName = name
        }
        session.start()
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
    let isEditing: Bool
    let onPlay: () -> Void

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
            if !isEditing {
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.body)
                        .foregroundStyle(.green)
                        .frame(width: 44, height: 44)
                        .background(Color.green.opacity(0.25), in: Circle())
                }
                .buttonStyle(.plain)
            }
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
        .environment(TabSelection())
}
