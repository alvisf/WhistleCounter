import XCTest
@testable import WhistleCounter

@MainActor
final class RecipeStoreTests: XCTestCase {

    private var tempFile: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("recipes-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFile)
        try await super.tearDown()
    }

    private func makeStore() -> RecipeStore {
        RecipeStore(fileURL: tempFile)
    }

    // MARK: - Seeding

    func testFirstLaunch_seedsDefaults() {
        let store = makeStore()
        XCTAssertEqual(store.recipes.count, Recipe.defaults.count)
    }

    func testFirstLaunch_persistsDefaultsToDisk() {
        _ = makeStore()
        let second = RecipeStore(fileURL: tempFile)
        XCTAssertEqual(second.recipes.count, Recipe.defaults.count)
    }

    // MARK: - Add

    func testAdd_appendsRecipe() {
        let store = makeStore()
        let before = store.recipes.count
        store.add(name: "Quinoa", whistleCount: 2)
        XCTAssertEqual(store.recipes.count, before + 1)
    }

    func testAdd_persistsAcrossReload() {
        let store = makeStore()
        store.add(name: "Quinoa", whistleCount: 2)
        let reloaded = RecipeStore(fileURL: tempFile)
        XCTAssertTrue(reloaded.recipes.contains { $0.name == "Quinoa" })
    }

    // MARK: - Update

    func testUpdate_changesExistingRecipe() {
        let store = makeStore()
        guard let first = store.recipes.first else {
            return XCTFail("store should be seeded")
        }
        let updated = Recipe(id: first.id, name: "Renamed", whistleCount: 9)
        store.update(updated)
        XCTAssertEqual(store.recipes.first?.name, "Renamed")
    }

    // MARK: - Delete

    func testDelete_removesRecipe() {
        let store = makeStore()
        guard let first = store.recipes.first else {
            return XCTFail("store should be seeded")
        }
        store.delete(first)
        XCTAssertFalse(store.recipes.contains(where: { $0.id == first.id }))
    }

    // MARK: - Restore defaults

    func testRestoreDefaults_replacesCurrentRecipesWithDefaults() {
        let store = makeStore()
        store.recipes.forEach { store.delete($0) }
        store.add(name: "Not a default", whistleCount: 1)
        store.restoreDefaults()
        XCTAssertEqual(store.recipes.count, Recipe.defaults.count)
        XCTAssertFalse(store.recipes.contains { $0.name == "Not a default" })
    }
}
