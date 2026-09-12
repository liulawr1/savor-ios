import Foundation

// Compile with the real Models.swift and PantryStore.swift. All writes are temporary.
@main struct PersistenceCheck {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("savor-equipment-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let ingredient = PantryItem(name: "Chickpeas", quantity: "1 can", category: "Protein")
        var recipe = Recipe(title: "Old saved meal", description: "An existing recipe.", minutes: 10, servings: 2, ingredients: [RecipeIngredient(pantryID: ingredient.id, name: ingredient.name, quantity: "1 can")], steps: ["Drain chickpeas.", "Serve."], why: "Uses the pantry.")
        recipe.completedSteps = [0]
        let encoder = JSONEncoder()
        // This is the old on-disk shape: no profile or requiredEquipment fields.
        let legacy: [String: Any] = ["pantry": try JSONSerialization.jsonObject(with: encoder.encode([ingredient])), "saved": try JSONSerialization.jsonObject(with: encoder.encode([recipe])), "sampleMode": false, "started": true]
        try JSONSerialization.data(withJSONObject: legacy).write(to: url)
        let store = PantryStore(storageURL: url)
        precondition(store.error == nil && store.equipment == nil)
        precondition(store.pantry == [ingredient] && store.saved == [recipe])
        precondition(store.saved[0].requiredEquipment == nil)
        precondition(store.setEquipment(["microwave"]))
        let reopened = PantryStore(storageURL: url)
        precondition(reopened.equipment == ["microwave"])
        precondition(reopened.pantry == [ingredient] && reopened.saved == [recipe])
        precondition(reopened.setEquipment([]))
        precondition(PantryStore(storageURL: url).equipment == [])
        precondition(reopened.setEquipment(["kettle"]))
        reopened.loadSample(); precondition(reopened.equipment == ["kettle"])
        reopened.loadSample(); reopened.clearSample()
        precondition(PantryStore(storageURL: url).equipment == ["kettle"])
        print("Legacy pantry/recipe migration, saved progress, profile persistence, empty profile, and sample transitions passed.")
    }
}
