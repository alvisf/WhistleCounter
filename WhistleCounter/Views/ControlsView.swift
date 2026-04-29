import SwiftUI

struct ControlsView: View {
    @Environment(WhistleSession.self) private var session

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if session.isListening {
                        session.stop()
                    } else {
                        session.start()
                    }
                } label: {
                    Label(
                        session.isListening ? "Stop" : "Start",
                        systemImage: session.isListening ? "stop.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(session.isListening ? .red : .green)

                Button {
                    session.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if let error = session.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    ControlsView()
        .environment(WhistleSession())
}
