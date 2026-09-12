import Foundation

@main struct CompletionCheck {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("savor-completion-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let finished = PantryItem(name: "Tomatoes", quantity: "1 cup", category: "Vegetables")
        let partial = PantryItem(name: "Spinach", quantity: "1 bag", category: "Vegetables", useSoon: true)
        let unused = PantryItem(name: "Lemon", quantity: "1", category: "Fruit")
        let unrelated = PantryItem(name: "Rice", quantity: "2 cups", category: "Grains")
        let items = [finished, partial, unused]
        let recipe = Recipe(title: "Pantry salad", description: "A simple bowl.", minutes: 10, servings: 2, ingredients: items.map { RecipeIngredient(pantryID: $0.id, name: $0.name, quantity: "a handful") } + [RecipeIngredient(pantryID: "water", name: "Water", quantity: "1 tbsp"), RecipeIngredient(pantryID: "missing", name: "Optional herbs", quantity: "a pinch")], steps: ["Prepare the ingredients.", "Combine and serve."], why: "Uses your pantry.")
        func fixture(_ name: String) -> PantryStore {
            let store = PantryStore(storageURL: root.appendingPathComponent(name + ".json"))
            precondition(store.add(items + [unrelated])); store.save(recipe); precondition(store.setEquipment(["microwave"]))
            return store
        }
        let review = [PantryCompletion(item: finished, usage: .usedAll), PantryCompletion(item: partial, usage: .someLeft, remainingAmount: "  a small handful  "), PantryCompletion(item: unused, usage: .didntUse)]
        let store = fixture("mixed")
        precondition(store.finish(recipe, updates: review))
        let reopened = PantryStore(storageURL: root.appendingPathComponent("mixed.json"))
        precondition(!reopened.pantry.contains { $0.id == finished.id })
        var expectedPartial = partial; expectedPartial.quantity = "a small handful"
        precondition(reopened.pantry.contains(expectedPartial))
        precondition(reopened.pantry.contains(unused) && reopened.pantry.contains(unrelated))
        precondition(reopened.equipment == ["microwave"])
        precondition(reopened.saved[0].cookedAt != nil && reopened.saved[0].completedSteps == [0, 1])
        precondition(reopened.saved[0].ingredients == recipe.ingredients)
        let savedBytes = try Data(contentsOf: root.appendingPathComponent("mixed.json"))
        precondition(!reopened.finish(recipe, updates: review))
        let afterDuplicate = try Data(contentsOf: root.appendingPathComponent("mixed.json")); precondition(afterDuplicate == savedBytes)
        print("Mixed outcomes persist; literal remaining amount, metadata, unrelated items and recipe preserved; duplicate completion rejected.")

        let invalid = fixture("invalid")
        let originalBytes = try Data(contentsOf: root.appendingPathComponent("invalid.json"))
        let badReviews = [
            [PantryCompletion(item: finished), review[1], review[2]],
            [review[0], PantryCompletion(item: partial, usage: .someLeft, remainingAmount: " \n "), review[2]],
            [review[0], PantryCompletion(item: partial, usage: .someLeft, remainingAmount: String(repeating: "x", count: 61)), review[2]],
            Array(review.dropLast()), review + [review[0]],
            review + [PantryCompletion(item: unrelated, usage: .usedAll)]
        ]
        for updates in badReviews {
            precondition(!invalid.finish(recipe, updates: updates))
            precondition(invalid.pantry == items + [unrelated] && invalid.saved[0].cookedAt == nil)
            let afterInvalid = try Data(contentsOf: root.appendingPathComponent("invalid.json")); precondition(afterInvalid == originalBytes)
        }
        print("Missing choices, blank/oversized amounts, incomplete/duplicate reviews and unrelated edits cause no partial writes.")

        let stale = fixture("stale")
        var edited = partial; edited.quantity = "new amount"; stale.update(edited)
        precondition(!stale.finish(recipe, updates: review))
        precondition(stale.pantry.contains(edited) && stale.pantry.contains(finished) && stale.saved[0].cookedAt == nil)
        let removed = fixture("removed"); removed.remove([finished.id])
        precondition(!removed.finish(recipe, updates: review)); precondition(removed.saved[0].cookedAt == nil)
        print("Changed or removed pantry entries invalidate an outdated review.")

        let noItems = fixture("none"); noItems.remove(Set(items.map(\.id)))
        precondition(noItems.finish(recipe, updates: []))
        precondition(noItems.pantry == [unrelated]); precondition(noItems.saved[0].cookedAt != nil)
        print("Recipes with no remaining pantry references complete without inventing pantry entries.")

        let failure = fixture("failure")
        let failureURL = root.appendingPathComponent("failure.json")
        try FileManager.default.removeItem(at: failureURL)
        try FileManager.default.createDirectory(at: failureURL, withIntermediateDirectories: false)
        precondition(!failure.finish(recipe, updates: review))
        precondition(failure.pantry == items + [unrelated] && failure.saved[0].cookedAt == nil)
        precondition(failure.error != nil)
        print("A filesystem write failure leaves pantry and meal history unchanged in memory.")
    }
}
