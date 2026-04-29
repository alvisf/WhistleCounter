import SwiftUI

/// Add / edit sheet for a recipe. Used in two modes:
/// - `recipe == nil`: adding a new recipe.
/// - `recipe != nil`: editing an existing recipe.
struct RecipeEditSheet: View {
    let recipe: Recipe?
    let onSave: (String, Int, AlarmSound?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AlarmSoundStore.self) private var alarmSoundStore

    @State private var name: String
    @State private var whistleCount: Int
    @State private var alarmSound: AlarmSound?

    init(recipe: Recipe?, onSave: @escaping (String, Int, AlarmSound?) -> Void) {
        self.recipe = recipe
        self.onSave = onSave
        _name = State(initialValue: recipe?.name ?? "")
        _whistleCount = State(initialValue: recipe?.whistleCount ?? 3)
        _alarmSound = State(initialValue: recipe?.alarmSound)
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

                Section("Alarm") {
                    NavigationLink {
                        AlarmSoundPickerView(
                            selection: $alarmSound,
                            includeDefaultOption: true,
                            defaultSound: alarmSoundStore.defaultSound
                        )
                    } label: {
                        HStack {
                            Text("Sound")
                            Spacer()
                            Text(alarmSoundLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
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
                        onSave(trimmed, whistleCount, alarmSound)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var alarmSoundLabel: String {
        alarmSound?.displayName ?? "Default"
    }
}
