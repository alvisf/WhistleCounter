import SwiftUI

struct CounterView: View {
    @Environment(WhistleSession.self) private var session

    private enum Layout {
        static let countFontSize: CGFloat = 90
        static let pickerHeight: CGFloat = 180
        static let targetRange = 1...20
    }

    var body: some View {
        if session.isListening || session.count > 0 {
            activeCountView
        } else {
            targetPickerView
        }
    }

    // MARK: - Active: big count display

    private var activeCountView: some View {
        VStack(spacing: 4) {
            Text("\(session.count)")
                .font(.system(size: Layout.countFontSize, weight: .thin))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.bouncy, value: session.count)

            Text("of \(session.targetCount)")
                .font(.title3.weight(.thin))
                .foregroundStyle(.gray)

            statusIndicator
                .frame(height: 20)
                .padding(.top, 8)
        }
    }

    // MARK: - Idle: scroll wheel picker

    private var targetPickerView: some View {
        @Bindable var session = session
        return Picker("Target", selection: $session.targetCount) {
            ForEach(Layout.targetRange, id: \.self) { n in
                HStack(spacing: 8) {
                    Text("\(n)")
                    // Invisible placeholder so each row is the same
                    // width as the "N Whistle" visual; the real
                    // "Whistle" word is a static overlay below.
                    Text("Whistle")
                        .fontWeight(.semibold)
                        .hidden()
                }
                .tag(n)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 180, height: Layout.pickerHeight)
        .overlay(alignment: .center) {
            HStack(spacing: 8) {
                // Spacer the width of the number column so "Whistle"
                // sits to the right of the selected number.
                Text("0").hidden()
                Text("Whistle")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Status indicator

    @ViewBuilder
    private var statusIndicator: some View {
        if session.isInterrupted {
            Label("Mic in use — listening paused", systemImage: "phone.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if session.isListening {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Listening…")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        } else {
            Text(" ")
                .font(.caption)
        }
    }
}

#Preview {
    CounterView()
        .environment(WhistleSession())
        .background(.black)
}
