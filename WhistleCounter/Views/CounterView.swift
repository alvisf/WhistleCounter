import SwiftUI

struct CounterView: View {
    @Environment(WhistleSession.self) private var session

    private enum Layout {
        static let countFontSize: CGFloat = 140
        static let indicatorDotSize: CGFloat = 8
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Whistles")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(session.count)")
                .font(.system(size: Layout.countFontSize,
                              weight: .bold,
                              design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.bouncy, value: session.count)

            Text("Target: \(session.targetCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if session.isListening {
                listeningIndicator
            }
        }
    }

    private var listeningIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: Layout.indicatorDotSize, height: Layout.indicatorDotSize)
            Text("Listening…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CounterView()
        .environment(WhistleSession())
}
