import Foundation

enum KitchenEquipment {
    static let all = ["microwave", "stovetop", "oven", "kettle"]
    static func label(_ value: String) -> String { value.prefix(1).uppercased() + value.dropFirst() }
    static func summary(_ values: [String]) -> String { values.isEmpty ? "No heating equipment" : values.map(label).joined(separator: ", ") }
}


struct PantryItem: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var name: String
    var quantity: String
    var category: String
    var useSoon = false
    var addedAt = Date()
    static let categories = ["Vegetables", "Fruit", "Protein", "Dairy", "Grains", "Other"]
    var symbol: String {
        switch category {
        case "Vegetables": return "carrot.fill"
        case "Fruit": return "apple.logo"
        case "Protein": return "fish.fill"
        case "Dairy": return "mug.fill"
        case "Grains": return "takeoutbag.and.cup.and.straw.fill"
        default: return "leaf.fill"
        }
    }
}

struct RecipeIngredient: Codable, Hashable {
    let pantryID: String
    let name: String
    let quantity: String
    var missing: Bool { pantryID == "missing" }
}
struct CookingPreferences: Codable, Equatable {
    var minutes: Int
    var servings: Int
    var style: String
    var allowShopping: Bool
}
struct Recipe: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var title: String
    var description: String
    var minutes: Int
    var servings: Int
    var ingredients: [RecipeIngredient]
    var steps: [String]
    var why: String
    var isSample = false
    var savedAt: Date?
    var completedSteps: [Int] = []
    var cookedAt: Date?
    var preferences: CookingPreferences?
    var adjustmentSummary: String?
    var originalRecipeID: String?
    var requiredEquipment: [String]?
    var adjustmentPreferences: CookingPreferences {
        preferences ?? CookingPreferences(minutes: [15, 30, 45].first { $0 >= minutes } ?? 45, servings: servings, style: "Anything", allowShopping: !missing.isEmpty)
    }
    var missing: [RecipeIngredient] { ingredients.filter(\.missing) }
    var progress: Double { steps.isEmpty ? 0 : Double(completedSteps.count) / Double(steps.count) }
    enum CodingKeys: String, CodingKey { case id, title, description, minutes, servings, ingredients, steps, why, isSample, savedAt, completedSteps, cookedAt, preferences, adjustmentSummary, originalRecipeID, requiredEquipment }
    init(title: String, description: String, minutes: Int, servings: Int, ingredients: [RecipeIngredient], steps: [String], why: String, isSample: Bool = false) {
        self.title = title; self.description = description; self.minutes = minutes; self.servings = servings
        self.ingredients = ingredients; self.steps = steps; self.why = why; self.isSample = isSample
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try c.decode(String.self, forKey: .title); description = try c.decode(String.self, forKey: .description)
        minutes = try c.decode(Int.self, forKey: .minutes); servings = try c.decode(Int.self, forKey: .servings)
        ingredients = try c.decode([RecipeIngredient].self, forKey: .ingredients); steps = try c.decode([String].self, forKey: .steps)
        why = try c.decode(String.self, forKey: .why); isSample = try c.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
        savedAt = try c.decodeIfPresent(Date.self, forKey: .savedAt); completedSteps = try c.decodeIfPresent([Int].self, forKey: .completedSteps) ?? []
        cookedAt = try c.decodeIfPresent(Date.self, forKey: .cookedAt)
        preferences = try c.decodeIfPresent(CookingPreferences.self, forKey: .preferences)
        adjustmentSummary = try c.decodeIfPresent(String.self, forKey: .adjustmentSummary)
        originalRecipeID = try c.decodeIfPresent(String.self, forKey: .originalRecipeID)
        requiredEquipment = try c.decodeIfPresent([String].self, forKey: .requiredEquipment)
    }
    var shareText: String { "\(title)\n\(minutes) min · Serves \(servings)\nEquipment: \(requiredEquipment.map { KitchenEquipment.summary($0) } ?? "Not recorded—check steps")\n\n" + ingredients.map { "\($0.quantity) \($0.name)" }.joined(separator: "\n") + "\n\n" + steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n\n") + "\n\nMade with Savor · \(isSample ? "Sample recipe" : "AI recipe—review before cooking")" }
}
struct ScanResult: Decodable {
    struct Item: Decodable { let name: String; let quantity: String; let category: String }
    let items: [Item]
    let note: String
}
enum SavorError: LocalizedError { case message(String); var errorDescription: String? { if case let .message(s) = self { return s }; return nil } }


enum IngredientUsage: String, CaseIterable {
    case usedAll, someLeft, didntUse
    var label: String {
        switch self {
        case .usedAll: return "Used it all"
        case .someLeft: return "Some left"
        case .didntUse: return "Didn’t use"
        }
    }
}
struct PantryCompletion: Identifiable {
    let item: PantryItem
    var usage: IngredientUsage?
    var remainingAmount = ""
    var id: String { item.id }
    var cleanedAmount: String { remainingAmount.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { usage != nil && (usage != .someLeft || (!cleanedAmount.isEmpty && cleanedAmount.count <= 60)) }
}
