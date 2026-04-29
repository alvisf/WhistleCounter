import Foundation
import Observation

/// Observable store for completed session history.
///
/// Records are kept sorted most-recent first. The store is append-only
/// from the session's side; the user can delete individual rows or
/// clear everything from the history tab.
@Observable
@MainActor
final class HistoryStore {

    // MARK: - Public state

    private(set) var records: [SessionRecord] = []

    // MARK: - Collaborators

    private let fileStore: JSONFileStore<[SessionRecord]>

    // MARK: - Init

    init(fileURL: URL) {
        self.fileStore = JSONFileStore(fileURL: fileURL)
        load()
    }

    convenience init() {
        self.init(fileURL: Self.defaultFileURL())
    }

    private static func defaultFileURL() -> URL {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        return documents.appendingPathComponent("history.json")
    }

    // MARK: - Actions

    func append(_ record: SessionRecord) {
        records.insert(record, at: 0)
        persist()
    }

    func delete(_ record: SessionRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        persist()
    }

    func clearAll() {
        records.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func load() {
        records = fileStore.load() ?? []
    }

    private func persist() {
        try? fileStore.save(records)
    }
}
