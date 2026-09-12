import SwiftUI

@MainActor final class PantryStore: ObservableObject {
    struct State: Codable { var pantry: [PantryItem] = []; var saved: [Recipe] = []; var sampleMode = false; var started = false }
    @Published private(set) var state = State()
    @Published var error: String?
    @Published var recipes: [Recipe] = []
    private let url: URL
    private var canWrite = true
    var pantry: [PantryItem] { state.pantry }
    var saved: [Recipe] { state.saved.sorted { ($0.savedAt ?? .distantPast) > ($1.savedAt ?? .distantPast) } }
    var useSoon: [PantryItem] { pantry.filter(\.useSoon) }
    var sampleMode: Bool { state.sampleMode }
    var mealsCooked: Int { state.saved.filter { $0.cookedAt != nil && !$0.isSample }.count }
    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(testing ? "SavorUITests/state.json" : "Savor/state.json")
        if ProcessInfo.processInfo.arguments.contains("--reset") && testing { try? FileManager.default.removeItem(at: url) }
        if FileManager.default.fileExists(atPath: url.path) {
            do { state = try JSONDecoder().decode(State.self, from: Data(contentsOf: url)) }
            catch { canWrite = false; self.error = "Your saved pantry could not be opened. Your file has been kept intact. Restart the app before making changes." }
        }
    }
    @discardableResult private func commit(_ next: State) -> Bool {
        guard canWrite else { error = "Your saved pantry needs recovery before it can be changed."; return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: url, options: [.atomic, .completeFileProtection])
            state = next; return true
        } catch { self.error = "Could not save your changes. Please check your device storage and try again."; return false }
    }
    func startEmpty() { var next = state; next.started = true; next.sampleMode = false; if commit(next) { recipes = [] } }
    func loadSample() {
        var next = State(); next.started = true; next.sampleMode = true
        next.pantry = [PantryItem(id: "spinach", name: "Spinach", quantity: "1 bag", category: "Vegetables", useSoon: true), PantryItem(id: "tomatoes", name: "Cherry tomatoes", quantity: "1 cup", category: "Vegetables", useSoon: true), PantryItem(id: "chickpeas", name: "Canned chickpeas", quantity: "1 can", category: "Protein"), PantryItem(id: "rice", name: "Dry rice", quantity: "1 cup", category: "Grains"), PantryItem(id: "lemon", name: "Lemon", quantity: "1", category: "Fruit"), PantryItem(id: "oil", name: "Olive oil", quantity: "3 tbsp", category: "Other")]
        if commit(next) { recipes = [] }
    }
    func clearSample() { if commit(State(pantry: [], saved: [], sampleMode: false, started: true)) { recipes = [] } }
    @discardableResult func add(_ items: [PantryItem]) -> Bool {
        guard state.pantry.count + items.count <= 30 else { error = "Your pantry holds up to 30 ingredients. Remove something you’ve used before adding more."; return false }
        var next = state; next.pantry.append(contentsOf: items); next.started = true
        if commit(next) { recipes = []; return true }; return false
    }
    func update(_ item: PantryItem) { var next = state; guard let i = next.pantry.firstIndex(where: { $0.id == item.id }) else { return }; next.pantry[i] = item; if commit(next) { recipes = [] } }
    func remove(_ ids: Set<String>) { var next = state; next.pantry.removeAll { ids.contains($0.id) }; if commit(next) { recipes = [] } }
    func save(_ recipe: Recipe) { var next = state; if !next.saved.contains(where: { $0.id == recipe.id }) { var r = recipe; r.savedAt = Date(); next.saved.append(r); commit(next) } }
    @discardableResult func acceptRevision(_ revision: Recipe, original: Recipe) -> Bool {
        var next = state
        if !next.saved.contains(where: { $0.id == original.id }) {
            var kept = original; kept.savedAt = kept.savedAt ?? Date(); next.saved.append(kept)
        }
        var fresh = revision
        fresh.savedAt = Date(); fresh.completedSteps = []; fresh.cookedAt = nil
        next.saved.append(fresh)
        return commit(next)
    }
    func unsave(_ id: String) { var next = state; next.saved.removeAll { $0.id == id }; commit(next) }
    func toggleStep(_ index: Int, recipe: Recipe) {
        var next = state; var r = next.saved.first(where: { $0.id == recipe.id }) ?? recipe
        if r.savedAt == nil { r.savedAt = Date() }
        if r.completedSteps.contains(index) { r.completedSteps.removeAll { $0 == index } } else { r.completedSteps.append(index) }
        if let i = next.saved.firstIndex(where: { $0.id == r.id }) { next.saved[i] = r } else { next.saved.append(r) }
        commit(next)
    }
    func finish(_ recipe: Recipe, remove ids: Set<String>) {
        var next = state; var r = next.saved.first(where: { $0.id == recipe.id }) ?? recipe
        r.savedAt = r.savedAt ?? Date(); r.cookedAt = Date(); r.completedSteps = Array(r.steps.indices)
        if let i = next.saved.firstIndex(where: { $0.id == r.id }) { next.saved[i] = r } else { next.saved.append(r) }
        next.pantry.removeAll { ids.contains($0.id) }
        if commit(next) { recipes = [] }
    }
    func current(_ recipe: Recipe) -> Recipe { state.saved.first(where: { $0.id == recipe.id }) ?? recipe }
    func sampleRecipes() -> [Recipe] {
        guard let url = Bundle.main.url(forResource: "sample-recipes", withExtension: "json"), let data = try? Data(contentsOf: url), let all = try? JSONDecoder().decode([Recipe].self, from: data) else { return [] }
        let ids = Set(pantry.map(\.id))
        return all.filter { $0.ingredients.allSatisfy { $0.pantryID == "water" || (!$0.missing && ids.contains($0.pantryID)) } }
    }
}
