import SwiftUI

@main
struct WhistleCounterApp: App {
    @State private var recipes = RecipeStore()
    @State private var history = HistoryStore()
    @State private var alarmSounds = AlarmSoundStore()
    @State private var session: WhistleSession

    init() {
        let history = HistoryStore()
        let alarmSounds = AlarmSoundStore()
        _history = State(initialValue: history)
        _alarmSounds = State(initialValue: alarmSounds)
        _session = State(
            initialValue: WhistleSession(
                historyStore: history,
                alarm: SystemAlarmPlayer(),
                alarmSoundStore: alarmSounds
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(recipes)
                .environment(history)
                .environment(alarmSounds)
        }
    }
}
