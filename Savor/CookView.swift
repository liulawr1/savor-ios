import SwiftUI

struct CookView: View {
    @EnvironmentObject var store: PantryStore
    @State private var minutes = 30
    @State private var servings = 2
    @State private var style = "Anything"
    @State private var shopping = false
    @State private var busy = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var activeRequest = UUID()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Eyebrow(text: "From what you have")
                    Text("What’s for\ndinner?").font(.system(size: 46, design: .serif)).tracking(-1.6)
                    Text("A few good ingredients. A fresh idea.").font(.subheadline).foregroundStyle(Palette.muted)
                    if store.pantry.isEmpty { EmptyCard(symbol: "carrot", title: "Start in your pantry.", message: "Add ingredients on the Pantry tab, then come back for meal ideas.") }
                    else {
                        HStack { Pill(text: "\(store.pantry.count) ingredients", symbol: "basket"); if !store.useSoon.isEmpty { Pill(text: "\(store.useSoon.count) to use soon", symbol: "sun.max", orange: true) } }.accessibilityElement(children: .combine)
                        if store.sampleMode {
                            VStack(alignment: .leading, spacing: 10) { Pill(text: "Sample kitchen", symbol: "play.circle"); Text("Three prepared ideas for the sample pantry. No AI calls.").font(.subheadline).foregroundStyle(Palette.muted) }.savorCard(Palette.sage.opacity(0.4))
                        } else {
                            VStack(alignment: .leading, spacing: 18) {
                                Eyebrow(text: "Make it yours")
                                HStack { Text("Time to cook").font(.subheadline.weight(.medium)); Spacer(); Picker("Time to cook", selection: $minutes) { ForEach([15, 30, 45], id: \.self) { Text("\($0) min").tag($0) } }.pickerStyle(.menu) }
                                Divider()
                                Stepper("Serves \(servings)", value: $servings, in: 1...4).font(.subheadline)
                                Divider()
                                HStack { Text("In the mood for").font(.subheadline); Spacer(); Picker("Cooking style", selection: $style) { ForEach(["Anything", "One pan", "No oven", "Vegetarian"], id: \.self) { Text($0) } }.pickerStyle(.menu) }
                                Divider()
                                Toggle("A few extras are okay", isOn: $shopping).font(.subheadline)
                                Text(shopping ? "Up to three missing ingredients per recipe, clearly listed." : "Only your listed ingredients, plus water. Add oil and seasonings to your pantry if you have them.").font(.caption).foregroundStyle(Palette.muted)
                            }.savorCard().disabled(busy)
                        }
                        ActionButton(title: busy ? "Finding your next meal…" : (store.sampleMode ? "Explore meal ideas" : "Find my meals"), symbol: "sparkles", disabled: busy) { generate() }.accessibilityIdentifier("generateMeals")
                        if busy { HStack { ProgressView().tint(Palette.green); Text("Starting with what you want to use soon.").font(.caption).foregroundStyle(Palette.muted) }; Button("Cancel") { activeRequest = UUID(); task?.cancel(); busy = false } }
                        if !store.sampleMode { Text("Your ingredient list and cooking preferences go to Google Gemini. Free-tier inputs may help improve Google’s products. Review ingredients and instructions before cooking; suggestions aren’t allergy guarantees.").font(.caption).foregroundStyle(Palette.muted).lineSpacing(3) }
                        if !store.recipes.isEmpty {
                            HStack { Text("Made for your pantry").font(.system(size: 27, design: .serif)); Spacer(); Text("\(store.recipes.count) ideas").font(.caption).foregroundStyle(Palette.muted) }
                            ForEach(Array(store.recipes.enumerated()), id: \.element.id) { index, recipe in
                                NavigationLink { RecipeDetailView(recipe: recipe) } label: { RecipeCard(recipe: recipe, index: index) }.buttonStyle(.plain).accessibilityIdentifier("recipeCard")
                            }
                        }
                    }
                }.padding(24).padding(.bottom, 20)
            }.pageStyle().toolbar(.hidden, for: .navigationBar)
            .alert("No meal ideas yet", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
            .onDisappear { activeRequest = UUID(); task?.cancel(); busy = false }
        }
    }
    private func generate() {
        if store.sampleMode { store.recipes = store.sampleRecipes(); if store.recipes.isEmpty { error = "The sample ingredients have changed. Reset the sample kitchen in Settings to explore its recipes, or switch to your own pantry for live AI." }; return }
        let pantry = store.pantry
        guard pantry.count <= 30 else { error = "For this demo, keep up to 30 ingredients in your pantry when asking for meals."; return }
        busy = true
        let requestID = UUID(); activeRequest = requestID
        task = Task { @MainActor in
            defer { if activeRequest == requestID { busy = false } }
            do { let recipes = try await APIService().meals(items: pantry, minutes: minutes, servings: servings, style: style, allowShopping: shopping); try Task.checkCancellation(); guard activeRequest == requestID else { return }; guard store.pantry == pantry else { error = "Your pantry changed. Find meals again with your updated ingredients."; return }; store.recipes = recipes }
            catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
struct RecipeCard: View {
    let recipe: Recipe
    var index = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ZStack(alignment: .topLeading) { (index % 2 == 0 ? Palette.sage.opacity(0.6) : Color(red: 0.95, green: 0.88, blue: 0.75)); BowlArt(variant: index).frame(height: 155).rotationEffect(.degrees(Double(index * 13 - 8))); Pill(text: recipe.isSample ? "Sample recipe" : "AI suggestion", symbol: "sparkles").padding(14) }.frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 19))
            HStack { Text("\(recipe.minutes) MIN · SERVES \(recipe.servings)").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(Palette.muted); Spacer(); Image(systemName: "arrow.up.right") }
            Text(recipe.title).font(.system(size: 26, design: .serif)).multilineTextAlignment(.leading)
            Text(recipe.description).font(.subheadline).foregroundStyle(Palette.muted).lineLimit(3).multilineTextAlignment(.leading)
            Pill(text: recipe.missing.isEmpty ? "From your pantry" : "\(recipe.missing.count) extras to pick up", symbol: recipe.missing.isEmpty ? "checkmark" : "basket", orange: !recipe.missing.isEmpty)
        }.savorCard()
    }
}
