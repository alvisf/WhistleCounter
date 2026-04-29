import Foundation

/// A recipe prescribes how many whistles a dish needs.
///
/// Users can add, edit, or delete recipes. The default recipe set is
/// re-seeded on a fresh install and can be restored at any time.
struct Recipe: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var whistleCount: Int

    init(id: UUID = UUID(), name: String, whistleCount: Int) {
        self.id = id
        self.name = name
        self.whistleCount = whistleCount
    }
}

extension Recipe {
    /// Seed recipes installed on first launch and re-installed when
    /// the user taps "Restore defaults".
    static let defaults: [Recipe] = [
        Recipe(name: "White rice",     whistleCount: 3),
        Recipe(name: "Brown rice",     whistleCount: 5),
        Recipe(name: "Toor dal",       whistleCount: 4),
        Recipe(name: "Chana dal",      whistleCount: 5),
        Recipe(name: "Rajma",          whistleCount: 6),
        Recipe(name: "Chickpeas",      whistleCount: 7),
        Recipe(name: "Chicken curry",  whistleCount: 4),
        Recipe(name: "Mutton curry",   whistleCount: 6),
        Recipe(name: "Potatoes",       whistleCount: 2),
        Recipe(name: "Beets",          whistleCount: 4),
    ]
}
