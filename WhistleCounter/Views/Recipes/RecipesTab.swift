import SwiftUI

struct RecipesTab: View {
    @Environment(RecipeStore.self) private var store
    @Environment(WhistleSession.self) private var session
    @Environment(TabSelection.self) private var tabs

    @State private var editing: Recipe?
    @State private var isAdding = false
    @State private var pendingRecipe: Recipe?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.recipes) { recipe in
                    RecipeRow(recipe: recipe) {
                        handleTap(recipe)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            store.delete(recipe)
                        }
                        Button("Edit") {
                            editing = recipe
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Restore defaults", systemImage: "arrow.counterclockwise") {
                            store.restoreDefaults()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                RecipeEditSheet(recipe: nil) { name, count, sound in
                    store.add(name: name, whistleCount: count, alarmSound: sound)
                }
            }
            .sheet(item: $editing) { recipe in
                RecipeEditSheet(recipe: recipe) { name, count, sound in
                    store.update(Recipe(
                        id: recipe.id,
                        name: name,
                        whistleCount: count,
                        alarmSound: sound
                    ))
                }
            }
            .confirmationDialog(
                "Replace current session?",
                isPresented: replaceSessionConfirmation,
                titleVisibility: .visible,
                presenting: pendingRecipe
            ) { recipe in
                Button("Replace", role: .destructive) {
                    startRecipe(recipe)
                }
                Button("Cancel", role: .cancel) {
                    pendingRecipe = nil
                }
            } message: { _ in
                Text("A session is in progress. Starting a new recipe will end it.")
            }
        }
    }

    // MARK: - Tap handling

    private func handleTap(_ recipe: Recipe) {
        if session.hasActiveSession {
            pendingRecipe = recipe
        } else {
            startRecipe(recipe)
        }
    }

    private func startRecipe(_ recipe: Recipe) {
        session.startFresh(with: recipe)
        tabs.select(.counter)
        pendingRecipe = nil
    }

    /// Drives the confirmation dialog. `pendingRecipe != nil` means
    /// the user tapped a recipe while a session was active and we're
    /// waiting for them to confirm or cancel.
    private var replaceSessionConfirmation: Binding<Bool> {
        Binding(
            get: { pendingRecipe != nil },
            set: { newValue in
                if !newValue { pendingRecipe = nil }
            }
        )
    }
}

private struct RecipeRow: View {
    let recipe: Recipe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("^[\(recipe.whistleCount) whistle](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
        }
    }
}

#Preview {
    RecipesTab()
        .environment(WhistleSession())
        .environment(RecipeStore(fileURL: URL(filePath: "/tmp/recipes-preview.json")))
        .environment(AlarmSoundStore())
        .environment(TabSelection())
}
