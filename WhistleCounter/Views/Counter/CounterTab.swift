import SwiftUI

/// The Counter tab — the original single-screen experience.
struct CounterTab: View {
    @Environment(WhistleSession.self) private var session

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                CounterView()
                Spacer()
                ControlsView()
                    .padding(.horizontal)
                SettingsView()
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .background(Color(.systemBackground))
            .alert("Target reached!", isPresented: targetReachedBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(session.count) whistles. Time to turn off the heat.")
            }
        }
    }

    /// Two-way binding on `session.targetReached` that can only be
    /// *dismissed* via the UI (setting it back to true from a view is
    /// meaningless).
    private var targetReachedBinding: Binding<Bool> {
        Binding(
            get: { session.targetReached },
            set: { _ in session.dismissTargetAlert() }
        )
    }
}

#Preview {
    CounterTab()
        .environment(WhistleSession())
}
