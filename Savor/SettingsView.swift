import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) var dismiss
    @State private var message = ""
    @State private var checking = false
    @State private var resetting = false
    @State private var clearing = false
    @State private var equipment = false
    var body: some View {
        NavigationStack {
            Form {
                Section { HStack(spacing: 12) { Image(systemName: "leaf.fill").font(.title); VStack(alignment: .leading) { Text("savor").font(.system(size: 32, design: .serif)); Text("Good food. Already here.").font(.caption).foregroundStyle(Palette.muted) } } }
                Section("Your kitchen") {
                    LabeledContent("Mode", value: store.sampleMode ? "Sample kitchen" : "My pantry")
                    if store.sampleMode { Button("Start my own pantry") { clearing = true }; Button("Reset sample kitchen") { resetting = true } }
                    else if store.pantry.isEmpty && store.saved.isEmpty { Button("Explore the sample kitchen") { store.loadSample(); dismiss() } }
                    LabeledContent("Meals made", value: String(store.mealsCooked))
                    Text("Sample meals don’t count toward meals made.").font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Kitchen equipment") {
                    Button { equipment = true } label: {
                        VStack(alignment: .leading, spacing: 6) { Text("Edit equipment"); Text(store.equipment.map { KitchenEquipment.summary($0) } ?? "Not set up yet").font(.caption).foregroundStyle(Palette.muted) }
                    }.accessibilityIdentifier("settingsEquipment")
                }
                Section("AI connection") {
                    Text("Savor uses Google Gemini to recognize ingredients and suggest meals. Your pantry works offline; AI features need a connection.").font(.subheadline)
                    Button { Task { checking = true; defer { checking = false }; do { let ready = try await APIService().health(); message = ready ? "Connected. Your kitchen is ready for AI." : "The server is reachable, but its Gemini key isn’t configured yet." } catch { message = error.localizedDescription } } } label: { HStack { Text("Check connection"); Spacer(); if checking { ProgressView() } else { Image(systemName: "arrow.triangle.2.circlepath") } } }.disabled(checking)
                    if !message.isEmpty { Text(message).font(.caption).foregroundStyle(Palette.muted) }
                }
                Section("Your ingredients, your choice") {
                    Text("Pantry items, saved recipes, and progress stay on this device. Scanned photos are not saved by Savor’s server.")
                    Text("Scanning sends your selected photo to Google. Meal suggestions send your ingredient list, equipment profile, and preferences. Adjustments also send the recipe and your change request. Google may use free-tier inputs and outputs to improve its products, including human review. Don’t include personal or sensitive information.")
                    Link("Google Gemini data-use terms", destination: URL(string: "https://ai.google.dev/gemini-api/terms")!)
                    Text("AI can make mistakes. Confirm scanned items and check recipe ingredients. Savor doesn’t assess freshness or guarantee allergen-free meals.")
                }.font(.subheadline)
                Section { Text("Savor · MVP 0.1").font(.caption).foregroundStyle(Palette.muted) }
            }.scrollContentBackground(.hidden).pageStyle().navigationTitle("Your kitchen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $equipment) { EquipmentProfileView(equipment: store.equipment) }
            .confirmationDialog("Replace the sample pantry and its recipes?", isPresented: $resetting, titleVisibility: .visible) { Button("Reset sample kitchen", role: .destructive) { store.loadSample(); dismiss() } }
            .confirmationDialog("Clear the sample kitchen and start fresh?", isPresented: $clearing, titleVisibility: .visible) { Button("Clear sample & start fresh", role: .destructive) { store.clearSample(); dismiss() } }
        }
    }
}
