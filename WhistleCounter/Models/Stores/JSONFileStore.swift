import Foundation

/// A tiny file-backed JSON store for `Codable` values.
///
/// Owned by the concrete stores (`RecipeStore`, `HistoryStore`) so
/// they don't each reinvent the same load/save plumbing. The store
/// accepts an arbitrary base directory so it can point at a temp
/// directory in tests without touching real user data.
struct JSONFileStore<Value: Codable> {
    let fileURL: URL
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    init(
        fileURL: URL,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.fileURL = fileURL
        self.encoder = encoder
        self.decoder = decoder
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parent, withIntermediateDirectories: true
        )
        let data = try encoder.encode(value)
        try data.write(to: fileURL, options: .atomic)
    }
}
