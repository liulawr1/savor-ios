import SwiftUI

struct RecipeAdjustmentView: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) private var dismiss
    let original: Recipe
    let onAccept: (Recipe) -> Bool
    @State private var request = ""
    @State private var preferences: CookingPreferences
    @State private var excludedIDs: Set<String> = []
    @State private var proposal: Recipe?
    @State private var submittedEquipment: [String] = []
    @State private var submittedPantry: [PantryItem] = []
    @State private var busy = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var activeRequest = UUID()
    @FocusState private var editingRequest: Bool

    init(original: Recipe, onAccept: @escaping (Recipe) -> Bool) {
        self.original = original; self.onAccept = onAccept
        _preferences = State(initialValue: original.adjustmentPreferences)
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                    Text(original.title).font(.system(size: 28, design: .serif))
                    if let proposal {
                        preview(proposal)
                    } else {
                        editor
                    }
                    }.padding(24).id("adjustmentTop")
                }.scrollDismissesKeyboard(.interactively).pageStyle()
                .onChange(of: proposal?.id) { _, _ in scroll.scrollTo("adjustmentTop", anchor: .top) }
            }
            .navigationTitle(proposal == nil ? "Make this work" : "Review the revision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { cancel(); dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingRequest = false } }
            }
            .alert("Couldn’t adjust this recipe", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
            .onDisappear { cancel() }
        }
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Almost right? Tell us what needs to change. You’ll review a new version before saving it.").font(.subheadline).foregroundStyle(Palette.muted)
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "What would help?")
                TextField("For example: Can I use a microwave?", text: $request, axis: .vertical)
                    .lineLimit(3...6).focused($editingRequest)
                    .onChange(of: request) { _, value in request = String(value.prefix(600)) }
                    .accessibilityIdentifier("adjustmentRequest")
                Text("\(request.count)/600").font(.caption.monospacedDigit()).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .trailing)
                Button("I only have a microwave") { request = "I only have a microwave. Adapt the preparation for microwave cooking." }
                    .font(.subheadline).accessibilityIdentifier("microwaveAdjustment")
            }.savorCard().disabled(busy)
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Keep it practical")
                if original.preferences == nil { Text("This older recipe didn’t save its cooking preferences. Check these limits before adjusting.").font(.caption).foregroundStyle(Palette.muted) }
                HStack { Text("Time limit"); Spacer(); Picker("Time limit", selection: $preferences.minutes) { ForEach([15, 30, 45], id: \.self) { Text("\($0) min").tag($0) } }.pickerStyle(.menu) }
                Stepper("Serves \(preferences.servings)", value: $preferences.servings, in: 1...4)
                HStack { Text("Cooking style"); Spacer(); Picker("Cooking style", selection: $preferences.style) { ForEach(["Anything", "One pan", "No oven", "Vegetarian"], id: \.self) { Text($0) } }.pickerStyle(.menu) }
                Toggle("A few extras are okay", isOn: $preferences.allowShopping)
                Text(preferences.allowShopping ? "Up to three missing ingredients. Items you leave out stay excluded." : "Your current pantry plus water. No assumed oil or seasonings.").font(.caption).foregroundStyle(Palette.muted)
            }.font(.subheadline).savorCard().disabled(busy)
            EquipmentProfileCard().disabled(busy)
            if !store.pantry.isEmpty {
                DisclosureGroup("Leave out ingredients (\(excludedIDs.count))") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Out of something? Exclude it from this revision. This won’t remove it from your pantry.").font(.caption).foregroundStyle(Palette.muted)
                        ForEach(store.pantry) { item in
                            Toggle(item.name, isOn: Binding(get: { excludedIDs.contains(item.id) }, set: { if $0 { excludedIDs.insert(item.id) } else { excludedIDs.remove(item.id) } }))
                        }
                    }.padding(.top, 14)
                }.font(.subheadline).savorCard().disabled(busy)
            }
            Text("Your current pantry, recipe, and request go to Google Gemini. Free-tier inputs may help improve Google’s products. Keep personal information out of your request.").font(.caption).foregroundStyle(Palette.muted)
            ActionButton(title: busy ? "Reworking your recipe…" : "Adjust recipe", symbol: "sparkles", disabled: busy || request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.pantry.isEmpty || store.equipment == nil) { generate() }.accessibilityIdentifier("submitAdjustment")
            if busy { HStack { ProgressView(); Text("Your original stays as it is.").font(.caption) }; Button("Cancel request") { cancel() }.accessibilityIdentifier("cancelAdjustment") }
        }
    }
    private func preview(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "What changed")
                Text(recipe.adjustmentSummary ?? "Review the revised ingredients and steps.").font(.subheadline).lineSpacing(4).accessibilityIdentifier("adjustmentSummary")
            }.savorCard(Palette.sage.opacity(0.5))
            Text(recipe.title).font(.system(size: 30, design: .serif)).accessibilityIdentifier("revisionTitle")
            Text("\(recipe.minutes) MIN · SERVES \(recipe.servings)").font(.caption.monospaced()).foregroundStyle(Palette.muted)
            Text(recipe.description).font(.subheadline)
            RecipeEquipmentView(recipe: recipe)
            Text("The ingredients").font(.system(size: 25, design: .serif))
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, item in
                HStack { VStack(alignment: .leading) { Text(item.name); Text(item.missing ? "Pick up" : item.pantryID == "water" ? "Kitchen tap" : "From your pantry").font(.caption).foregroundStyle(item.missing ? Palette.orange : Palette.muted) }; Spacer(); Text(item.quantity).multilineTextAlignment(.trailing) }.font(.subheadline)
            }
            Text("The new steps").font(.system(size: 25, design: .serif))
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) { Text("\(index + 1).").foregroundStyle(Palette.green); Text(step).frame(maxWidth: .infinity, alignment: .leading) }.font(.subheadline).lineSpacing(4)
            }
            Text("Check that this addresses your request, including equipment, ingredients, and dietary needs. Your original and its progress will stay in Recipe box. This version starts a fresh checklist.").font(.caption).foregroundStyle(Palette.muted)
            ActionButton(title: "Use this version", symbol: "checkmark") {
                guard store.pantry == submittedPantry && store.equipment == submittedEquipment else { proposal = nil; error = "Your pantry or equipment changed. Adjust the recipe again with your current ingredients."; return }
                if onAccept(recipe) { dismiss() } else { error = store.error ?? "The revised recipe couldn’t be saved." }
            }.accessibilityIdentifier("acceptAdjustment")
            Button("Edit my request") { proposal = nil }.font(.subheadline).accessibilityIdentifier("editAdjustment")
            Button("Keep original") { dismiss() }.font(.subheadline).accessibilityIdentifier("keepOriginal")
        }
    }
    private func cancel() {
        activeRequest = UUID(); task?.cancel(); busy = false
    }
    private func generate() {
        guard !original.isSample, !store.sampleMode else { error = "Sample recipes stay offline. Choose an AI recipe in your own pantry."; return }
        guard let equipment = store.equipment else { error = "Set up your kitchen equipment first."; return }
        editingRequest = false
        let pantry = store.pantry
        let snapshotPreferences = preferences
        let snapshotRequest = request.trimmingCharacters(in: .whitespacesAndNewlines)
        let excluded = excludedIDs
        submittedPantry = pantry; submittedEquipment = equipment; busy = true
        let requestID = UUID(); activeRequest = requestID
        task = Task { @MainActor in
            defer { if activeRequest == requestID { busy = false } }
            do {
                let result = try await APIService().adjust(recipe: original, items: pantry, preferences: snapshotPreferences, request: snapshotRequest, excludedIDs: excluded, equipment: equipment)
                try Task.checkCancellation()
                guard activeRequest == requestID else { return }
                guard store.pantry == pantry && store.equipment == equipment else { error = "Your pantry or equipment changed. Try again with your current ingredients."; return }
                proposal = result
            } catch is CancellationError {
            } catch { if activeRequest == requestID { self.error = error.localizedDescription } }
        }
    }
}
