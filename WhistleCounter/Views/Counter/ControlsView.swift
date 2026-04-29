import SwiftUI

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
            Label(listenTitle, systemImage: listenSystemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(session.isListening ? .red : .green)
    }

    private var resetButton: some View {
        Button(action: session.reset) {
            Label("Reset", systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func errorLabel(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
    }

    // MARK: - Listen button appearance

    private var listenTitle: String {
        session.isListening ? "Stop" : "Start"
    }

    private var listenSystemImage: String {
        session.isListening ? "stop.fill" : "play.fill"
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
}
