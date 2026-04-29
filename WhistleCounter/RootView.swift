import SwiftUI

/// The app's root. Hosts the tab bar and owns the shared stores.
struct RootView: View {
    @Environment(WhistleSession.self) private var session
    @Environment(RecipeStore.self) private var recipes
    @Environment(HistoryStore.self) private var history

    var body: some View {
        TabView {
            Tab("Counter", systemImage: "timer") {
                CounterTab()
            }
            Tab("Recipes", systemImage: "book.pages.fill") {
                RecipesTab()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryTab()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(WhistleSession())
        .environment(RecipeStore(fileURL: URL(filePath: "/tmp/recipes-preview.json")))
        .environment(HistoryStore(fileURL: URL(filePath: "/tmp/history-preview.json")))
}
