import Foundation

/// A saved record of a completed whistle-counting session.
///
/// Written to history when the session ends with at least one whistle.
struct SessionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let whistleCount: Int
    let recipeName: String?

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        whistleCount: Int,
        recipeName: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.whistleCount = whistleCount
        self.recipeName = recipeName
    }

    var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}
