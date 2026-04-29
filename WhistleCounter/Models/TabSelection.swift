import Foundation
import Observation

/// Tracks which tab is selected. Owned by `RootView` and injected so
/// any view can programmatically switch tabs (e.g. Recipes ->
/// Counter after applying a recipe).
@Observable
@MainActor
final class TabSelection {
    enum Tab: Hashable {
        case counter, recipes, history
    }

    var current: Tab = .counter

    func select(_ tab: Tab) {
        current = tab
    }
}
