import SwiftUI

struct RecipesTab: View {
    @Environment(RecipeStore.self) private var store
    @Environment(WhistleSession.self) private var session

    @State private var editing: Recipe?
    @State private var isAdding = false
    @State private var selectedRecipeID: Recipe.ID?

    var body: some View {
        NavigationStack {
            List(selection: $selectedRecipeID) {
                ForEach(store.recipes) { recipe in
                    RecipeRow(recipe: recipe) {
                        session.apply(recipe: recipe)
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
                RecipeEditSheet(recipe: nil) { name, count in
                    store.add(name: name, whistleCount: count)
                }
            }
            .sheet(item: $editing) { recipe in
                RecipeEditSheet(recipe: recipe) { name, count in
                    store.update(Recipe(id: recipe.id, name: name, whistleCount: count))
                }
            }
        }
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
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    RecipesTab()
        .environment(WhistleSession())
        .environment(RecipeStore(fileURL: URL(filePath: "/tmp/recipes-preview.json")))
}
