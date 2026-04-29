import SwiftUI

@main
struct WhistleCounterApp: App {
    @State private var session = WhistleSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
