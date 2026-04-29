import SwiftUI

struct ContentView: View {
    @Environment(WhistleSession.self) private var session

    var body: some View {
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
        .alert(
            "Target reached!",
            isPresented: Binding(
                get: { session.targetReached },
                set: { _ in session.dismissTargetAlert() }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(session.count) whistles. Time to turn off the heat.")
        }
    }
}

#Preview {
    ContentView()
        .environment(WhistleSession())
}
