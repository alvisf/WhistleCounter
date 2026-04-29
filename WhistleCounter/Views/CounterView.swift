import SwiftUI

struct CounterView: View {
    @Environment(WhistleSession.self) private var session

    var body: some View {
        VStack(spacing: 8) {
            Text("Whistles")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("\(session.count)")
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.bouncy, value: session.count)
            Text("Target: \(session.targetCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if session.isListening {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(session.isListening ? 1 : 0)
                    Text("Listening…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    CounterView()
        .environment(WhistleSession())
}
