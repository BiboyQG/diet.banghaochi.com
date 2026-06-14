import SwiftUI

@MainActor
struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let entry: Entry?
    @State private var draft = EntryDraft()
    @State private var isSaving = false

    init(entry: Entry? = nil) {
        self.entry = entry
        _draft = State(initialValue: entry.map(EntryDraft.init(entry:)) ?? EntryDraft())
    }

    private var macroCalories: Double {
        NutritionCalculations.macroCalories(
            carbsG: draft.carbsG,
            proteinG: draft.proteinG,
            fatG: draft.fatG
        )
    }

    private var hasMacroWarning: Bool {
        NutritionCalculations.shouldWarnMacroCalories(
            caloriesKcal: draft.caloriesKcal,
            carbsG: draft.carbsG,
            proteinG: draft.proteinG,
            fatG: draft.fatG
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Slot", selection: $draft.mealSlot) {
                        ForEach(MealSlot.allCases) { slot in
                            Label(slot.title, systemImage: slot.systemImage).tag(slot)
                        }
                    }
                    TextField("Name", text: $draft.name)
                } header: {
                    SectionLabel(title: "Meal", systemImage: "fork.knife")
                }

                Section {
                    numberField("Calories", value: $draft.caloriesKcal, identifier: "entry.calories")
                    numberField("Carbs", value: $draft.carbsG, identifier: "entry.carbs")
                    numberField("Protein", value: $draft.proteinG, identifier: "entry.protein")
                    numberField("Fat", value: $draft.fatG, identifier: "entry.fat")
                    numberField("Water", value: $draft.waterMl, identifier: "entry.water")
                } header: {
                    SectionLabel(title: "Nutrition", systemImage: "chart.pie.fill")
                } footer: {
                    Label("Macro estimate: \(macroCalories.formatted(.number.precision(.fractionLength(0)))) kcal", systemImage: hasMacroWarning ? "exclamationmark.triangle.fill" : "flame.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(hasMacroWarning ? .orange : .secondary)
                        .padding(.top, 2)
                }
            }
            .navigationTitle(entry == nil ? "Add entry" : "Edit entry")
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
                    .disabled(!draft.isValid || isSaving)
                    .accessibilityIdentifier("entry.save")
                }
            }
        }
    }

    private func numberField(
        _ label: String,
        value: Binding<Double>,
        identifier: String
    ) -> some View {
        TextField(label, value: value, format: .number)
            .keyboardType(.decimalPad)
            .accessibilityIdentifier(identifier)
    }

    private func save() async {
        guard draft.isValid else { return }
        isSaving = true
        if let entry {
            await store.updateEntry(entry, draft: draft)
        } else {
            await store.saveEntry(draft)
        }
        isSaving = false
        dismiss()
    }
}

#Preview("Entry editor") {
    EntryEditorView()
        .environment(AppStore.previewLoaded)
}
