import XCTest
@testable import WhistleCounter

@MainActor
final class HistoryStoreTests: XCTestCase {

    private var tempFile: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFile)
        try await super.tearDown()
    }

    private func makeStore() -> HistoryStore {
        HistoryStore(fileURL: tempFile)
    }

    private func makeRecord(
        count: Int = 3,
        recipe: String? = nil
    ) -> SessionRecord {
        let now = Date()
        return SessionRecord(
            startedAt: now,
            endedAt: now.addingTimeInterval(60),
            whistleCount: count,
            recipeName: recipe
        )
    }

    // MARK: - Empty state

    func testFirstLaunch_isEmpty() {
        let store = makeStore()
        XCTAssertTrue(store.records.isEmpty)
    }

    // MARK: - Append

    func testAppend_addsRecord() {
        let store = makeStore()
        store.append(makeRecord())
        XCTAssertEqual(store.records.count, 1)
    }

    func testAppend_newestFirst() {
        let store = makeStore()
        let older = makeRecord(count: 1)
        let newer = makeRecord(count: 2)
        store.append(older)
        store.append(newer)
        XCTAssertEqual(store.records.first?.whistleCount, 2)
    }

    func testAppend_persistsAcrossReload() {
        let store = makeStore()
        store.append(makeRecord(count: 5))
        let reloaded = HistoryStore(fileURL: tempFile)
        XCTAssertEqual(reloaded.records.first?.whistleCount, 5)
    }

    // MARK: - Delete

    func testDelete_removesRecord() {
        let store = makeStore()
        let record = makeRecord()
        store.append(record)
        store.delete(record)
        XCTAssertTrue(store.records.isEmpty)
    }

    // MARK: - Clear all

    func testClearAll_emptiesStore() {
        let store = makeStore()
        store.append(makeRecord(count: 1))
        store.append(makeRecord(count: 2))
        store.clearAll()
        XCTAssertTrue(store.records.isEmpty)
    }

    func testClearAll_persistsAcrossReload() {
        let store = makeStore()
        store.append(makeRecord())
        store.clearAll()
        let reloaded = HistoryStore(fileURL: tempFile)
        XCTAssertTrue(reloaded.records.isEmpty)
    }
}
