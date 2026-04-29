import SwiftUI

@main
struct WhistleCounterApp: App {
    @State private var recipes = RecipeStore()
    @State private var history = HistoryStore()
    @State private var session: WhistleSession

    init() {
        let history = HistoryStore()
        _history = State(initialValue: history)
        _session = State(
            initialValue: WhistleSession(
                historyStore: history,
                alarm: SystemAlarmPlayer()
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(recipes)
                .environment(history)
        }
    }
}
