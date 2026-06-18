import SwiftUI

@MainActor
struct FoodDescriptionEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var descriptionText = ""
    @State private var availability: FoodDescriptionParserAvailability = .unavailable("Checking Apple Intelligence...")
    @State private var estimate: FoodDescriptionEstimate?
    @State private var draft = EntryDraft()
    @State private var noteText = ""
    @State private var isEstimating = false
    @State private var isSaving = false
    @State private var errorMessage: String?

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

    private var canEstimate: Bool {
        availability.isAvailable &&
            !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !isEstimating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. two large eggs and a banana", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("natural.description")

                    Button {
                        Task { await estimateFood() }
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            if isEstimating {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                                Text("Estimating…")
                            } else {
                                Image(systemName: "sparkles")
                                Text(estimate == nil ? "Estimate nutrition" : "Re-estimate")
                            }
                            Spacer()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandLeaf)
                    .disabled(!canEstimate)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .accessibilityIdentifier("natural.estimate")

                    availabilityMessage
                } header: {
                    SectionLabel(title: "Describe food", systemImage: "sparkles")
                } footer: {
                    Text("Review the estimate before saving. Apple Intelligence runs this on device when available.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let estimate {
                    Section {
                        if !estimate.servingDescription.isEmpty {
                            Label(estimate.servingDescription, systemImage: "scalemass")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        confidenceMeter(estimate)
                        detailList(
                            "Assumptions",
                            values: estimate.assumptions,
                            systemImage: "info.circle",
                            tint: .secondary
                        )
                        detailList(
                            "Warnings",
                            values: estimate.warnings,
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    } header: {
                        SectionLabel(title: "Estimate", systemImage: "wand.and.stars")
                    }

                    Section {
                        Picker("Slot", selection: $draft.mealSlot) {
                            ForEach(MealSlot.allCases) { slot in
                                Label(slot.title, systemImage: slot.systemImage).tag(slot)
                            }
                        }
                        TextField("Name", text: $draft.name)
                            .accessibilityIdentifier("natural.name")
                    } header: {
                        SectionLabel(title: "Entry", systemImage: "fork.knife")
                    }

                    Section {
                        numberField("Calories", value: $draft.caloriesKcal, identifier: "natural.calories")
                        numberField("Carbs", value: $draft.carbsG, identifier: "natural.carbs")
                        numberField("Protein", value: $draft.proteinG, identifier: "natural.protein")
                        numberField("Fat", value: $draft.fatG, identifier: "natural.fat")
                        numberField("Water", value: $draft.waterMl, identifier: "natural.water")
                    } header: {
                        SectionLabel(title: "Nutrition", systemImage: "chart.pie.fill")
                    } footer: {
                        Label("Macro estimate: \(macroCalories.formatted(.number.precision(.fractionLength(0)))) kcal", systemImage: hasMacroWarning ? "exclamationmark.triangle.fill" : "flame.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(hasMacroWarning ? .orange : .secondary)
                            .padding(.top, 2)
                    }

                    Section {
                        TextEditor(text: $noteText)
                            .frame(minHeight: 90)
                            .accessibilityIdentifier("natural.notes")
                    } header: {
                        SectionLabel(title: "Notes", systemImage: "note.text")
                    }
                }
            }
            .navigationTitle("Describe food")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.brand)
            .task {
                availability = await store.foodDescriptionAvailability()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving" : "Save") {
                        Task { await save() }
                    }
                    .disabled(estimate == nil || !draft.isValid || isSaving)
                    .accessibilityIdentifier("natural.save")
                }
            }
        }
    }

    @ViewBuilder
    private var availabilityMessage: some View {
        switch availability {
        case .available:
            Label("Apple Intelligence ready", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.brand)
        case .unavailable(let message):
            Label(message, systemImage: "info.circle")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func confidenceMeter(_ estimate: FoodDescriptionEstimate) -> some View {
        let fraction = min(max(estimate.confidence, 0), 1)
        let tint: Color = fraction >= 0.7 ? .brandLeaf : (fraction >= 0.4 ? .macroAmber : .orange)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Confidence", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(estimate.confidence, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 7)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func detailList(
        _ title: String,
        values: [String],
        systemImage: String,
        tint: Color
    ) -> some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(values, id: \.self) { value in
                    Label(value, systemImage: systemImage)
                        .font(.footnote)
                        .foregroundStyle(tint)
                }
            }
            .padding(.vertical, 2)
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

    private func estimateFood() async {
        errorMessage = nil
        isEstimating = true
        defer { isEstimating = false }

        do {
            let estimate = try await store.estimateFoodDescription(descriptionText)
            withAnimation(.easeInOut(duration: 0.25)) {
                self.estimate = estimate
                draft = EntryDraft(estimate: estimate)
                noteText = draft.notes ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard estimate != nil, draft.isValid else { return }
        isSaving = true
        draft.notes = noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : noteText
        await store.saveEntry(draft)
        isSaving = false
        dismiss()
    }
}

#Preview("Describe food") {
    FoodDescriptionEntryView()
        .environment(
            AppStore(
                client: .mock(),
                foodDescriptionParser: .mock(
                    estimate: FoodDescriptionEstimate(
                        sourceDescription: "two eggs and a banana",
                        name: "Eggs and banana",
                        servingDescription: "2 large eggs and 1 medium banana",
                        mealSlot: .breakfast,
                        caloriesKcal: 245,
                        carbsG: 27,
                        proteinG: 13,
                        fatG: 10,
                        waterMl: 0,
                        confidence: 0.72,
                        assumptions: ["Large eggs", "Medium banana"],
                        warnings: ["Brands and sizes can vary"]
                    )
                )
            )
        )
}
