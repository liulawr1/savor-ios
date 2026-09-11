import SwiftUI
import PhotosUI

struct AddIngredientsView: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) var dismiss
    @State private var method = 0
    @State private var drafts = [PantryItem(name: "", quantity: "", category: "Vegetables")]
    @State private var selection: PhotosPickerItem?
    @State private var photo: Data?
    @State private var camera = false
    @State private var busy = false
    @State private var loadingPhoto = false
    @State private var scanned = false
    @State private var note = ""
    @State private var error: String?
    @State private var scanTask: Task<Void, Never>?
    @State private var activeScan = UUID()
    private var valid: [PantryItem] { drafts.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var body: some View {
        NavigationStack {
            Form {
                Section { Picker("Add ingredients", selection: $method) { Text("Type it in").tag(0); Text("Scan a photo").tag(1) }.pickerStyle(.segmented).disabled(busy) }
                if method == 1 {
                    Section {
                        if let photo, let image = UIImage(data: photo) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16)) }
                        PhotosPicker(selection: $selection, matching: .images) { Label(photo == nil ? "Choose a photo" : "Choose another photo", systemImage: "photo") }.disabled(busy || loadingPhoto)
                        Button { Task { let available = UIImagePickerController.isSourceTypeAvailable(.camera); let allowed = available ? await PhotoTools.cameraAccess() : false; if allowed { camera = true } else { error = "The camera isn’t available. Choose a photo, or enable camera access in iPhone Settings." } } } label: { Label("Take a photo", systemImage: "camera") }.disabled(busy || loadingPhoto)
                        if loadingPhoto { ProgressView("Opening photo…") }
                        if store.sampleMode { Text("The sample kitchen is offline. Switch to your own pantry in Settings to scan real ingredients.").font(.caption).foregroundStyle(Palette.muted) }
                        Button { scan() } label: { HStack { if busy { ProgressView() }; Text(busy ? "Looking at your ingredients…" : "Scan ingredients"); Spacer(); Image(systemName: "sparkles") } }.disabled(photo == nil || busy || loadingPhoto || store.sampleMode)
                        if busy { Button("Cancel scan") { activeScan = UUID(); scanTask?.cancel(); busy = false } }
                    } footer: { Text("Only this photo is sent to Google Gemini. Google may use free-tier inputs to improve its products. Keep personal information out of the frame. You’ll check every ingredient before adding it.") }
                }
                if method == 0 || scanned {
                    Section {
                        if scanned { Text(note.isEmpty ? "Check names and amounts before adding." : note).font(.subheadline).foregroundStyle(Palette.muted) }
                        ForEach($drafts) { $item in
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Ingredient name", text: $item.name).font(.headline).onChange(of: item.name) { _, v in item.name = String(v.prefix(60)) }.accessibilityIdentifier("ingredientName")
                                TextField("Amount, e.g. 1 can or a handful", text: $item.quantity).onChange(of: item.quantity) { _, v in item.quantity = String(v.prefix(60)) }.accessibilityIdentifier("ingredientQuantity")
                                Picker("Category", selection: $item.category) { ForEach(PantryItem.categories, id: \.self) { Text($0) } }
                                Toggle("Use soon", isOn: $item.useSoon).font(.subheadline)
                            }.padding(.vertical, 5)
                        }.onDelete { drafts.remove(atOffsets: $0) }
                        Button { drafts.append(PantryItem(name: "", quantity: "", category: "Vegetables")) } label: { Label("Add another ingredient", systemImage: "plus") }.disabled(drafts.count >= 15)
                    } header: { Text(scanned ? "Review ingredients" : "What’s in your kitchen?") } footer: { Text("Amounts are a starting point. Check what you have before cooking. Swipe a row to remove it. “Use soon” is your reminder, not an expiry prediction.") }
                }
            }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).pageStyle().navigationTitle(scanned ? "Check the ingredients" : "Add ingredients").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { scanTask?.cancel(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add \(valid.count)") {
                    let items = valid.map { value -> PantryItem in var item = value; item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines); item.quantity = item.quantity.trimmingCharacters(in: .whitespacesAndNewlines); if item.quantity.isEmpty { item.quantity = "Check amount" }; return item }
                    if store.add(items) { dismiss() } else { error = store.error; store.error = nil }
                }.disabled(valid.isEmpty || busy || loadingPhoto || (method == 1 && !scanned)).accessibilityIdentifier("confirmIngredients") }
            }
            .task(id: selection) {
                guard let selection else { return }; loadingPhoto = true
                defer { loadingPhoto = false }
                do { let data = try await PhotoTools.load(selection); try Task.checkCancellation(); photo = data; scanned = false }
                catch is CancellationError {} catch { self.error = error.localizedDescription }
            }
            .sheet(isPresented: $camera) { CameraPicker(onPhoto: { photo = $0; scanned = false }, onError: { error = $0 }) }
            .alert("Let’s try that again", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
            .onDisappear { scanTask?.cancel() }
        }
    }
    private func scan() {
        guard let photo else { return }; busy = true
        let requestID = UUID(); activeScan = requestID
        scanTask = Task { @MainActor in
            defer { if activeScan == requestID { busy = false } }
            do { let result = try await APIService().scan(photo); try Task.checkCancellation(); guard activeScan == requestID else { return }; drafts = result.items.map { PantryItem(name: $0.name, quantity: $0.quantity, category: $0.category) }; note = result.note; scanned = true }
            catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
