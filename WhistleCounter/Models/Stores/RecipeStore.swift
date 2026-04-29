import Foundation
import Observation

/// Observable store for the user's recipes.
///
/// On first launch (empty file) the defaults are seeded. Add / edit /
/// delete / restore-defaults all persist immediately. Writes are
/// synchronous so the on-disk file is always consistent with the
/// observable `recipes` array.
@Observable
@MainActor
final class RecipeStore {

    // MARK: - Public state

    private(set) var recipes: [Recipe] = []

    // MARK: - Collaborators

    private let fileStore: JSONFileStore<[Recipe]>

    // MARK: - Init

    init(fileURL: URL) {
        self.fileStore = JSONFileStore(fileURL: fileURL)
        load()
    }

    /// Convenience init that points at the app's Documents folder.
    convenience init() {
        let url = Self.defaultFileURL()
        self.init(fileURL: url)
    }

    private static func defaultFileURL() -> URL {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        return documents.appendingPathComponent("recipes.json")
    }

    // MARK: - Actions

    func add(name: String, whistleCount: Int, alarmSound: AlarmSound? = nil) {
        let recipe = Recipe(
            name: name,
            whistleCount: whistleCount,
            alarmSound: alarmSound
        )
        recipes.append(recipe)
        persist()
    }

    func update(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else {
            return
        }
        recipes[index] = recipe
        persist()
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        recipes.remove(atOffsets: offsets)
        persist()
    }

    func restoreDefaults() {
        recipes = Recipe.defaults
        persist()
    }

    // MARK: - Persistence

    private func load() {
        if let stored = fileStore.load() {
            recipes = stored
        } else {
            recipes = Recipe.defaults
            persist()
        }
    }

    private func persist() {
        try? fileStore.save(recipes)
    }
}
