import SwiftUI

@MainActor
struct BodyWeightEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var weightKg: Double
    @State private var notes = ""
    @State private var isSaving = false

    init(initialWeightKg: Double) {
        _weightKg = State(initialValue: initialWeightKg)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Weight", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold))
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                } header: {
                    SectionLabel(title: "Body weight", systemImage: "scalemass.fill")
                }
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving" : "Save") {
                        Task { await save() }
                    }
                    .disabled(weightKg <= 0 || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard weightKg > 0 else { return }
        isSaving = true
        await store.saveBodyWeight(
            weightKg: weightKg,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        isSaving = false
        dismiss()
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview("Body weight") {
    BodyWeightEditorView(initialWeightKg: 70)
        .environment(AppStore.previewLoaded)
}
