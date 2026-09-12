import SwiftUI

struct EquipmentProfileView: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>
    init(equipment: [String]?) { _selected = State(initialValue: Set(equipment ?? [])) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("What’s in your kitchen?").font(.system(size: 29, design: .serif))
                    Text("Choose the appliances you can use. We’ll apply this to every meal suggestion and recipe adjustment.").font(.subheadline).foregroundStyle(Palette.muted)
                }
                Section("Available equipment") {
                    ForEach(KitchenEquipment.all, id: \.self) { item in
                        Toggle(KitchenEquipment.label(item), isOn: Binding(get: { selected.contains(item) }, set: { if $0 { selected.insert(item) } else { selected.remove(item) } }))
                            .accessibilityIdentifier("equipment-\(item)")
                    }
                }
                Section {
                    Text(selected.isEmpty ? "Nothing selected? Save for meals that need no heating equipment." : KitchenEquipment.summary(KitchenEquipment.all.filter { selected.contains($0) }))
                    Text("We assume basic utensils and suitable cookware. A kettle is for boiling water only. Recipes will tell you when you need a microwave-safe or heat-safe container.")
                }.font(.subheadline).foregroundStyle(Palette.muted)
                Section { Text("Your pantry and saved recipes stay as they are. New suggestions use this profile; saved recipes show if their equipment no longer fits.").font(.caption).foregroundStyle(Palette.muted) }
            }.scrollContentBackground(.hidden).pageStyle().navigationTitle("Kitchen equipment").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.setEquipment(selected) { dismiss() } }.accessibilityIdentifier("saveEquipment") }
            }
        }
    }
}

struct EquipmentProfileCard: View {
    @EnvironmentObject var store: PantryStore
    @State private var editing = false
    var body: some View {
        Button { editing = true } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "oven").foregroundStyle(Palette.green)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your equipment").font(.subheadline.weight(.semibold))
                    Text(store.equipment.map { KitchenEquipment.summary($0) } ?? "Set up your kitchen before asking for meals.").font(.subheadline).foregroundStyle(Palette.muted)
                }
                Spacer(); Image(systemName: "chevron.right").font(.caption)
            }.frame(maxWidth: .infinity, alignment: .leading).savorCard()
        }.buttonStyle(.plain).accessibilityIdentifier("editEquipment")
        .sheet(isPresented: $editing) { EquipmentProfileView(equipment: store.equipment) }
    }
}

struct RecipeEquipmentView: View {
    @EnvironmentObject var store: PantryStore
    let recipe: Recipe
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Equipment needed")
            if let required = recipe.requiredEquipment {
                Text(KitchenEquipment.summary(required)).font(.subheadline).accessibilityIdentifier("requiredEquipment")
                if recipe.isSample {
                    Text("Sample recipe equipment is shown for reference.").font(.caption).foregroundStyle(Palette.muted)
                } else if let available = store.equipment {
                    let missing = required.filter { !available.contains($0) }
                    if !missing.isEmpty { Text("Outside your current profile: \(missing.map(KitchenEquipment.label).joined(separator: ", ")). Use Make this work to request a revision.").font(.caption).foregroundStyle(Palette.orange).accessibilityIdentifier("equipmentMismatch") }
                } else {
                    Text("Set your kitchen profile to compare equipment.").font(.caption).foregroundStyle(Palette.muted)
                }
            } else {
                Text("Equipment wasn’t recorded for this older recipe. Check its steps or request a revision using your kitchen profile.").font(.caption).foregroundStyle(Palette.muted).accessibilityIdentifier("equipmentUnknown")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).savorCard(Palette.sage.opacity(0.3))
    }
}
