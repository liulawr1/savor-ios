import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject var store: PantryStore
    let recipe: Recipe
    @State private var finishing = false
    @State private var adjusting = false
    @State private var revision: Recipe?
    var displayed: Recipe { revision ?? recipe }
    var current: Recipe { store.current(displayed) }
    var isSaved: Bool { store.saved.contains { $0.id == displayed.id } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                BowlArt().frame(height: 230).frame(maxWidth: .infinity).background(Palette.sage.opacity(0.5), in: RoundedRectangle(cornerRadius: 28))
                HStack { Pill(text: displayed.isSample ? "Sample recipe" : "AI suggestion", symbol: "sparkles"); Spacer(); Text("\(displayed.minutes) MIN · SERVES \(displayed.servings)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted) }
                Text(displayed.title).font(.system(size: 37, design: .serif)).tracking(-0.7)
                Text(displayed.description).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4)
                HStack(alignment: .top, spacing: 12) { Image(systemName: "sun.max").foregroundStyle(Palette.orange); Text(displayed.why).font(.subheadline).lineSpacing(3) }.savorCard(Color(red: 0.98, green: 0.93, blue: 0.84))
                if let summary = displayed.adjustmentSummary {
                    VStack(alignment: .leading, spacing: 8) { Eyebrow(text: "What changed"); Text(summary).font(.subheadline).lineSpacing(3) }.savorCard(Palette.sage.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 10) {
                    ActionButton(title: "Make this work", symbol: "wand.and.stars", disabled: displayed.isSample || store.sampleMode || store.pantry.isEmpty) { adjusting = true }.accessibilityIdentifier("makeThisWork")
                    Text(displayed.isSample || store.sampleMode ? "Sample recipes stay offline. Adjust an AI recipe in your own pantry." : store.pantry.isEmpty ? "Add ingredients to your pantry before adjusting this recipe." : "Different equipment or an ingredient missing? Review a revision while keeping your original.").font(.caption).foregroundStyle(Palette.muted)
                }
                RecipeEquipmentView(recipe: displayed)
                HStack { Text("The ingredients").font(.system(size: 27, design: .serif)); Spacer(); Text("\(displayed.ingredients.count) items").font(.caption).foregroundStyle(Palette.muted) }
                VStack(spacing: 15) {
                    ForEach(Array(displayed.ingredients.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top) { Image(systemName: item.missing ? "plus.circle" : "checkmark.circle").foregroundStyle(item.missing ? Palette.orange : Palette.green); VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.subheadline.weight(.medium)); Text(item.missing ? "Pick up" : (item.pantryID == "water" ? "Kitchen tap" : (store.pantry.contains { $0.id == item.pantryID } ? "In your pantry · check amount" : "Used or removed from pantry"))).font(.caption).foregroundStyle(item.missing ? Palette.orange : Palette.muted) }; Spacer(); Text(item.quantity).font(.subheadline).multilineTextAlignment(.trailing) }
                    }
                }.savorCard()
                Text("Check amounts, labels, and dietary needs before cooking. Savor can’t verify freshness or allergens. The bowl artwork is an illustration.").font(.caption).foregroundStyle(Palette.muted)
                HStack { Text("Let’s make it").font(.system(size: 27, design: .serif)); Spacer(); Text("\(current.completedSteps.count)/\(displayed.steps.count)").font(.caption.monospacedDigit()).foregroundStyle(Palette.muted) }
                ProgressView(value: current.progress).tint(Palette.green)
                VStack(spacing: 12) {
                    ForEach(Array(displayed.steps.enumerated()), id: \.offset) { index, step in
                        Button { store.toggleStep(index, recipe: displayed) } label: {
                            HStack(alignment: .top, spacing: 15) {
                                ZStack { Circle().fill(current.completedSteps.contains(index) ? Palette.green : Palette.sage).frame(width: 32, height: 32); if current.completedSteps.contains(index) { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } else { Text(String(format: "%02d", index+1)).font(.system(size: 12, weight: .semibold, design: .monospaced)) } }
                                Text(step).font(.system(size: 15)).lineSpacing(5).frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                            }.savorCard(current.completedSteps.contains(index) ? Palette.sage.opacity(0.25) : .white)
                        }.buttonStyle(.plain).disabled(current.cookedAt != nil).accessibilityLabel("Step \(index+1). \(step)").accessibilityValue(current.completedSteps.contains(index) ? "Completed" : "Not completed").accessibilityIdentifier("step-\(index)")
                    }
                }
                if current.cookedAt != nil { Label("A good meal, made by you.", systemImage: "checkmark.seal.fill").font(.headline).frame(maxWidth: .infinity).savorCard(Palette.sage) }
                else { ActionButton(title: "I made this", symbol: "checkmark", disabled: current.completedSteps.count != displayed.steps.count) { finishing = true }.accessibilityIdentifier("finishCooking") }
                Link("Safe cooking temperatures", destination: URL(string: "https://www.foodsafety.gov/food-safety-charts/safe-minimum-internal-temperatures")!).font(.caption).padding(.bottom, 16)
            }.padding(24)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { ShareLink(item: displayed.shareText) { Image(systemName: "square.and.arrow.up") }; Button { store.save(displayed) } label: { Image(systemName: isSaved ? "bookmark.fill" : "bookmark") }.disabled(isSaved).accessibilityLabel(isSaved ? "Recipe saved" : "Save recipe").accessibilityIdentifier("saveRecipe") } }
        .sheet(isPresented: $finishing) { FinishMealView(recipe: current, items: store.pantry.filter { item in current.ingredients.contains { $0.pantryID == item.id } }) }
        .sheet(isPresented: $adjusting) {
            RecipeAdjustmentView(original: current) { proposed in
                guard store.acceptRevision(proposed, original: current) else { return false }
                revision = proposed
                return true
            }
        }
    }
}
struct FinishMealView: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) var dismiss
    let recipe: Recipe
    @State private var updates: [PantryCompletion]
    @State private var error: String?
    @FocusState private var editingAmount: String?
    init(recipe: Recipe, items: [PantryItem]) {
        self.recipe = recipe
        _updates = State(initialValue: items.map { PantryCompletion(item: $0) })
    }
    private var ready: Bool { updates.allSatisfy(\.isValid) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("What’s left in your kitchen?").font(.system(size: 29, design: .serif))
                    Text("Review each ingredient before saving your meal. You decide what remains; we won’t subtract recipe quantities.").font(.subheadline).foregroundStyle(Palette.muted)
                }
                ForEach($updates) { $update in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(update.item.name).font(.headline)
                            Text("In your pantry: \(update.item.quantity)").font(.subheadline).foregroundStyle(Palette.muted)
                        }
                        HStack(spacing: 8) {
                            ForEach(IngredientUsage.allCases, id: \.self) { usage in
                                Button {
                                    update.usage = usage
                                    if usage != .someLeft && editingAmount == update.id { editingAmount = nil }
                                } label: {
                                    Text(usage.label).font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .padding(.horizontal, 4).padding(.vertical, 6)
                                        .background(update.usage == usage ? Palette.green : Palette.sage.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                                        .foregroundStyle(update.usage == usage ? .white : Palette.ink)
                                }.buttonStyle(.plain)
                                .accessibilityLabel("\(update.item.name): \(usage.label)")
                                .accessibilityAddTraits(update.usage == usage ? .isSelected : [])
                                .accessibilityIdentifier("usage-\(update.id)-\(usage.rawValue)")
                            }
                        }
                        if update.usage == .someLeft {
                            TextField("Amount remaining, e.g. half a bag", text: $update.remainingAmount)
                                .focused($editingAmount, equals: update.id)
                                .onChange(of: update.remainingAmount) { _, value in update.remainingAmount = String(value.prefix(60)) }
                                .accessibilityLabel("Amount remaining for \(update.item.name)")
                                .accessibilityIdentifier("remaining-\(update.id)")
                            Text("Enter what you actually have left—even “a handful.” This replaces the recorded amount.").font(.caption).foregroundStyle(Palette.muted)
                        } else if update.usage == .usedAll {
                            Text("Will be removed from your pantry.").font(.caption).foregroundStyle(Palette.orange)
                        } else if update.usage == .didntUse {
                            Text("Stays in your pantry with its current amount.").font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                }
                if updates.isEmpty { Section { Text("This recipe has no ingredients currently in your pantry. There’s nothing to update.").foregroundStyle(Palette.muted) } }
                Section {
                    if !ready { Text("Review each ingredient and enter an amount wherever you chose Some left.").font(.caption).foregroundStyle(Palette.muted) }
                    ActionButton(title: "Save this moment", symbol: "checkmark", disabled: !ready) {
                        editingAmount = nil
                        if store.finish(recipe, updates: updates) { dismiss() }
                        else { error = store.error; store.error = nil }
                    }.accessibilityIdentifier("confirmCooked")
                } footer: { Text("Nothing changes until you save. Water and ingredients outside your pantry aren’t added automatically.") }
            }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).pageStyle()
            .navigationTitle("Update your pantry").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.accessibilityIdentifier("cancelCooked") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingAmount = nil } }
            }
            .alert("Couldn’t save meal", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
        }
    }
}
struct SavedView: View {
    @EnvironmentObject var store: PantryStore
    @State private var filter = "All"
    var recipes: [Recipe] { store.saved.filter { filter != "Cooked" || $0.cookedAt != nil } }
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "Worth making again")
                Text("Your recipe box.").font(.system(size: 39, design: .serif)).tracking(-1)
                Text("Keep the good ones. Pick up where you left off.").font(.subheadline).foregroundStyle(Palette.muted)
                Picker("Recipes", selection: $filter) { Text("All").tag("All"); Text("Cooked").tag("Cooked") }.pickerStyle(.segmented)
                if recipes.isEmpty { EmptyCard(symbol: "bookmark", title: "A place for favorites.", message: "Save a meal from Cook. Your recipes and cooking progress will stay right here.") }
                ForEach(recipes) { recipe in
                    NavigationLink { RecipeDetailView(recipe: recipe) } label: { RecipeCard(recipe: recipe) }.buttonStyle(.plain).accessibilityIdentifier("recipeCard")
                    HStack { if recipe.cookedAt != nil { Label("Cooked", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.green) } else { Text("\(recipe.completedSteps.count) steps complete").foregroundStyle(Palette.muted) }; Spacer(); Button("Remove") { store.unsave(recipe.id) }.foregroundStyle(Palette.orange) }.font(.caption)
                }
            }.padding(24) }.pageStyle().toolbar(.hidden, for: .navigationBar)
        }
    }
}
