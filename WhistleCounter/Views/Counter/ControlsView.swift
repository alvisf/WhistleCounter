import SwiftUI

/// Clock-app-style Liquid Glass pills: centered label, no icon,
/// tinted to the button's role (green = start, red = stop).
struct ControlsView: View {
    @Environment(WhistleSession.self) private var session

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                listenToggleButton
                resetButton
            }
            if let error = session.errorMessage {
                errorLabel(error)
            }
        }
    }

    private var listenToggleButton: some View {
        Button(action: toggleListening) {
            Text(listenTitle)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.glass)
        .tint(session.isListening ? .red : .green)
        .controlSize(.large)
    }

    private var resetButton: some View {
        Button(action: session.reset) {
            Text("Reset")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }

    private func errorLabel(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
    }

    private var listenTitle: String {
        session.isListening ? "Stop" : "Start"
    }

    private func toggleListening() {
        if session.isListening {
            session.stop()
        } else {
            session.start()
        }
    }
}

#Preview {
    ControlsView()
        .environment(WhistleSession())
        .padding()
}
