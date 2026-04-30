import SwiftUI

/// The app's root. Hosts the tab bar and owns the shared stores.
struct RootView: View {
    @Environment(WhistleSession.self) private var session
    @Environment(RecipeStore.self) private var recipes
    @Environment(HistoryStore.self) private var history
    @Environment(TabSelection.self) private var tabs

    var body: some View {
        @Bindable var tabs = tabs

        TabView(selection: $tabs.current) {
            Tab("Counter", systemImage: "timer", value: TabSelection.Tab.counter) {
                CounterTab()
            }
            Tab("Recipes", systemImage: "book.pages.fill", value: TabSelection.Tab.recipes) {
                RecipesTab()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
        .environment(WhistleSession())
        .environment(RecipeStore(fileURL: URL(filePath: "/tmp/recipes-preview.json")))
        .environment(HistoryStore(fileURL: URL(filePath: "/tmp/history-preview.json")))
        .environment(TabSelection())
}
