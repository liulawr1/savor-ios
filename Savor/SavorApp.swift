import SwiftUI

@main struct SavorApp: App {
    @StateObject private var store = PantryStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(store).preferredColorScheme(.light) } }
}
struct RootView: View {
    @EnvironmentObject var store: PantryStore
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            PantryView(onCook: { tab = 1 }).tabItem { Label("Pantry", systemImage: "cabinet") }.tag(0)
            CookView().tabItem { Label("Cook", systemImage: "sparkles") }.tag(1)
            SavedView().tabItem { Label("Recipe box", systemImage: "bookmark") }.tag(2)
        }.tint(Palette.ink)
        .alert("Couldn’t save that", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
        .onAppear { if ProcessInfo.processInfo.arguments.contains("--sample") && !store.state.started { store.loadSample() } }
    }
}
struct PantryView: View {
    @EnvironmentObject var store: PantryStore
    var onCook: () -> Void
    @State private var adding = false
    @State private var settings = false
    @State private var editing: PantryItem?
    @State private var search = ""
    @State private var filter = "All"
    var visible: [PantryItem] { store.pantry.filter { (filter != "Use soon" || $0.useSoon) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }.sorted { $0.useSoon && !$1.useSoon } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center) {
                        HStack(spacing: 6) { Image(systemName: "leaf.fill").font(.system(size: 22)); Text("savor").font(.system(size: 42, weight: .regular, design: .serif)).tracking(-2) }
                        Spacer()
                        Button { settings = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 18)).padding(13).background(.white, in: Circle()) }.accessibilityLabel("Settings").accessibilityIdentifier("settings")
                    }
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(text: "Your everyday kitchen")
                            Text("Good food.\nAlready here.").font(.system(size: 34, weight: .regular, design: .serif)).tracking(-1).fixedSize(horizontal: false, vertical: true)
                            Text("A little inspiration.\nA lot less wasted.").font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(3)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        BowlArt().frame(width: 130, height: 175).rotationEffect(.degrees(-12))
                    }.padding(22).frame(maxWidth: .infinity).background(Palette.sage.opacity(0.6), in: RoundedRectangle(cornerRadius: 28))
                    if !store.state.started {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Let’s see what’s in.").font(.system(size: 27, design: .serif))
                            Text("Start with the food you have. We’ll help you decide what to make.").font(.subheadline).foregroundStyle(Palette.muted)
                            ActionButton(title: "Add my first ingredients", symbol: "plus") { adding = true }.accessibilityIdentifier("firstIngredients")
                            Button("Explore the sample kitchen") { store.loadSample() }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 6).accessibilityIdentifier("loadSample")
                        }.savorCard()
                    } else {
                        if store.sampleMode {
                            HStack { Pill(text: "Sample kitchen", symbol: "play.circle"); Spacer(); Text("No AI calls").font(.caption).foregroundStyle(Palette.muted) }
                        }
                        if !store.useSoon.isEmpty {
                            Button(action: onCook) {
                                HStack(spacing: 13) { Image(systemName: "sun.max.fill").foregroundStyle(Palette.orange).font(.title2); VStack(alignment: .leading, spacing: 4) { Text("First in line for dinner").font(.subheadline.weight(.semibold)); Text("\(store.useSoon.count) ingredients you marked to use soon").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Image(systemName: "arrow.up.right") }.savorCard(Color(red: 0.98, green: 0.92, blue: 0.83))
                            }.buttonStyle(.plain)
                        }
                        HStack { Text("Your pantry").font(.system(size: 28, design: .serif)); Text("\(store.pantry.count)").font(.caption.monospacedDigit()).padding(7).background(Palette.sage, in: Circle()); Spacer(); Button { adding = true } label: { Image(systemName: "plus").font(.headline).padding(11).background(Palette.ink, in: Circle()).foregroundStyle(.white) }.accessibilityLabel("Add ingredients").accessibilityIdentifier("addIngredients") }
                        HStack { Image(systemName: "magnifyingglass"); TextField("Find an ingredient", text: $search).font(.subheadline).accessibilityIdentifier("pantrySearch") }.foregroundStyle(Palette.muted).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 14))
                        HStack { ForEach(["All", "Use soon"], id: \.self) { choice in Button { filter = choice } label: { Text(choice).font(.subheadline.weight(.medium)).padding(.horizontal, 18).padding(.vertical, 10).background(filter == choice ? Palette.ink : .white, in: Capsule()).foregroundStyle(filter == choice ? .white : Palette.ink) }.buttonStyle(.plain) }; Spacer() }
                        if visible.isEmpty { EmptyCard(symbol: "basket", title: store.pantry.isEmpty ? "Room for good things." : "Nothing here yet.", message: store.pantry.isEmpty ? "Add a few ingredients to find your next meal." : "Try another search or filter.") }
                        VStack(spacing: 0) {
                            ForEach(visible) { item in
                                Button { editing = item } label: {
                                    HStack(spacing: 14) { Image(systemName: item.symbol).font(.system(size: 23)).frame(width: 46, height: 48).foregroundStyle(item.useSoon ? Palette.orange : Palette.green).background(item.useSoon ? Palette.orange.opacity(0.08) : Palette.sage.opacity(0.5), in: RoundedRectangle(cornerRadius: 13)); VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.system(size: 16, weight: .medium)); Text("\(item.quantity) · \(item.category)").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); if item.useSoon { Circle().fill(Palette.orange).frame(width: 7, height: 7) }; Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted) }.padding(.vertical, 13).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("ingredient-\(item.name)")
                                if item.id != visible.last?.id { Divider().overlay(Palette.line) }
                            }
                        }
                        if !store.pantry.isEmpty { ActionButton(title: "Make something delicious", symbol: "sparkles", action: onCook).accessibilityIdentifier("goCook") }
                    }
                    Text("A fuller plate. A lighter footprint.").font(.system(size: 12, design: .serif)).italic().foregroundStyle(Palette.muted).frame(maxWidth: .infinity).padding(.bottom, 8)
                }.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 24)
            }.scrollDismissesKeyboard(.interactively).pageStyle().toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $adding) { AddIngredientsView() }
            .sheet(isPresented: $settings) { SettingsView() }
            .sheet(item: $editing) { IngredientEditor(item: $0) }
        }
    }
}
struct IngredientEditor: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) var dismiss
    @State var item: PantryItem
    @State private var deleting = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") { TextField("Name", text: $item.name).onChange(of: item.name) { _, v in item.name = String(v.prefix(60)) }; TextField("Quantity", text: $item.quantity).onChange(of: item.quantity) { _, v in item.quantity = String(v.prefix(60)) }; Picker("Category", selection: $item.category) { ForEach(PantryItem.categories, id: \.self) { Text($0) } } }
                Section { Toggle("Use soon", isOn: $item.useSoon) } footer: { Text("A reminder you control. Savor doesn’t determine freshness or food safety from photos.") }
                Section { Button("Remove from pantry", role: .destructive) { deleting = true } }
            }.scrollContentBackground(.hidden).pageStyle().navigationTitle("Edit ingredient").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines); if item.quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { item.quantity = "Check amount" }; store.update(item); if store.error == nil { dismiss() } }.disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
            .confirmationDialog("Remove \(item.name)?", isPresented: $deleting, titleVisibility: .visible) { Button("Remove ingredient", role: .destructive) { store.remove([item.id]); if store.error == nil { dismiss() } } }
        }
    }
}
