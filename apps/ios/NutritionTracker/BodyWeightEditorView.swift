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
                Section("Body weight") {
                    TextField("Weight", value: $weightKg, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
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
