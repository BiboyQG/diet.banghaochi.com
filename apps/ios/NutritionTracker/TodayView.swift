import SwiftUI

@MainActor
struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var sheet: TodaySheet?
    @State private var entryPendingDelete: Entry?

    var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                ProgressView("Loading today")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { await store.load() }
            case .failed(let message):
                ContentUnavailableView("Could not load today", systemImage: "exclamationmark.triangle", description: Text(message))
                    .toolbar {
                        Button("Retry") {
                            Task { await store.load() }
                        }
                    }
            case .loaded:
                if let day = store.today {
                    todayContent(day)
                } else {
                    EmptyStateView(title: "No day loaded", systemImage: "calendar.badge.exclamationmark")
                }
            }
        }
        .navigationTitle("Today")
        .sheet(item: $sheet) { destination in
            switch destination {
            case .entry(let entry):
                EntryEditorView(entry: entry)
            case .bodyWeight(let initialWeightKg):
                BodyWeightEditorView(initialWeightKg: initialWeightKg)
            }
        }
        .confirmationDialog("Delete entry?", isPresented: deleteConfirmation) {
            if let entryPendingDelete {
                Button("Delete", role: .destructive) {
                    let entry = entryPendingDelete
                    self.entryPendingDelete = nil
                    Task { await store.deleteEntry(entry) }
                }
            }
            Button("Cancel", role: .cancel) {
                entryPendingDelete = nil
            }
        } message: {
            Text("This removes the entry from today's totals.")
        }
    }

    private var deleteConfirmation: Binding<Bool> {
        Binding(
            get: { entryPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    entryPendingDelete = nil
                }
            }
        )
    }

    private func todayContent(_ day: DayLog) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                dayTypeControl(day)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    MetricCard(title: "Eaten", value: day.totals.caloriesKcal, unit: "kcal")
                    MetricCard(
                        title: "Remaining",
                        value: day.calculated.remainingIntakeKcal,
                        unit: "kcal",
                        tint: day.calculated.remainingIntakeKcal < 0 ? .red : .green
                    )
                    MetricCard(title: "Deficit", value: day.calculated.actualDeficitKcal, unit: "kcal")
                }

                VStack(spacing: 14) {
                    ProgressMetric(title: "Calories", value: day.totals.caloriesKcal, target: day.intakeTargetKcal, unit: "kcal")
                    ProgressMetric(title: "Carbs", value: day.totals.carbsG, target: day.carbsTargetG, unit: "g")
                    ProgressMetric(title: "Protein", value: day.totals.proteinG, target: day.proteinTargetG, unit: "g")
                    ProgressMetric(title: "Fat", value: day.totals.fatG, target: day.fatTargetG, unit: "g")
                    ProgressMetric(title: "Water", value: day.totals.waterMl, target: day.waterTargetMl, unit: "ml")
                }
                .card()

                quickActions
                bodyWeight(day)
                entries(day.entries)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            Button {
                sheet = .entry(nil)
            } label: {
                Label("Add entry", systemImage: "plus")
            }
            .accessibilityIdentifier("today.addEntry")
        }
        .refreshable {
            await store.refreshToday()
        }
    }

    private func dayTypeControl(_ day: DayLog) -> some View {
        HStack(spacing: 10) {
            ForEach(DayType.allCases) { dayType in
                dayTypeButton(dayType, isSelected: day.dayType == dayType)
            }
        }
    }

    @ViewBuilder
    private func dayTypeButton(_ dayType: DayType, isSelected: Bool) -> some View {
        let button = Button {
            Task { await store.setDayType(dayType) }
        } label: {
            Text(dayType.title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .accessibilityIdentifier("today.dayType.\(dayType.rawValue)")

        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered).tint(.secondary)
        }
    }

    private var quickActions: some View {
        HStack {
            Button {
                Task { await store.addWater(250) }
            } label: {
                Label("+250 ml", systemImage: "drop")
            }

            Button {
                Task { await store.addWater(500) }
            } label: {
                Label("+500 ml", systemImage: "drop.fill")
            }

            Button {
                sheet = .entry(nil)
            } label: {
                Label("Quick add", systemImage: "plus")
            }
        }
        .buttonStyle(.bordered)
    }

    private func bodyWeight(_ day: DayLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Body weight")
                .font(.headline)
            Text(day.bodyWeight.map { "\($0.weightKg.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "No weight logged")
                .foregroundStyle(.secondary)
            Button {
                sheet = .bodyWeight(day.bodyWeight?.weightKg ?? store.profile?.currentWeightKg ?? 0)
            } label: {
                Label(day.bodyWeight == nil ? "Log weight" : "Update weight", systemImage: "scalemass")
            }
            .buttonStyle(.bordered)
        }
        .card()
    }

    private func entries(_ entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Entries")
                .font(.headline)
            if entries.isEmpty {
                Text("No entries yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) {
                            Text(entry.name)
                                .fontWeight(.semibold)
                            Text(entry.mealSlot.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.caloriesKcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                            .fontWeight(.semibold)
                        Button {
                            sheet = .entry(entry)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("entry.edit.\(entry.id)")

                        Button(role: .destructive) {
                            entryPendingDelete = entry
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("entry.delete.\(entry.id)")
                    }
                    if index < entries.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .card()
    }
}

private enum TodaySheet: Identifiable {
    case entry(Entry?)
    case bodyWeight(Double)

    var id: String {
        switch self {
        case .entry(let entry):
            entry?.id ?? "new-entry"
        case .bodyWeight:
            "body-weight"
        }
    }
}

#Preview("Today") {
    NavigationStack {
        TodayView()
            .environment(AppStore.previewLoaded)
    }
}
