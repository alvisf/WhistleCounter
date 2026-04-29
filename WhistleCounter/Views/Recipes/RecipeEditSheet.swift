import SwiftUI

/// Add / edit sheet for a recipe. Used in two modes:
/// - `recipe == nil`: adding a new recipe.
/// - `recipe != nil`: editing an existing recipe; the closure receives
///   the new name and whistle count, caller reconstructs the record.
struct RecipeEditSheet: View {
    let recipe: Recipe?
    let onSave: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var whistleCount: Int

    init(recipe: Recipe?, onSave: @escaping (String, Int) -> Void) {
        self.recipe = recipe
        self.onSave = onSave
        _name = State(initialValue: recipe?.name ?? "")
        _whistleCount = State(initialValue: recipe?.whistleCount ?? 3)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Stepper(
                        "Whistles: \(whistleCount)",
                        value: $whistleCount,
                        in: 1...20
                    )
                }
            }
            .navigationTitle(recipe == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        onSave(trimmed, whistleCount)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview("New") {
    RecipeEditSheet(recipe: nil) { _, _ in }
}

#Preview("Edit") {
    RecipeEditSheet(
        recipe: Recipe(name: "Toor dal", whistleCount: 4)
    ) { _, _ in }
}
