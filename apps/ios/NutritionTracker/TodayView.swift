import SwiftUI

@MainActor
struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var sheet: TodaySheet?
    @State private var entryPendingDelete: Entry?
    @State private var templatePendingDelete: FoodTemplate?

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
            case .template(let template):
                FoodTemplateEditorView(template: template)
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
        .confirmationDialog("Delete common food?", isPresented: templateDeleteConfirmation) {
            if let templatePendingDelete {
                Button("Delete", role: .destructive) {
                    let template = templatePendingDelete
                    self.templatePendingDelete = nil
                    Task { await store.deleteFoodTemplate(template) }
                }
            }
            Button("Cancel", role: .cancel) {
                templatePendingDelete = nil
            }
        } message: {
            Text("This removes the saved shortcut. Existing entries stay logged.")
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

    private var templateDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { templatePendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    templatePendingDelete = nil
                }
            }
        )
    }

    private func todayContent(_ day: DayLog) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dayTypeControl(day)
                calorieHero(day)
                statCards(day)
                macroCard(day)
                quickActions
                commonFoods
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
        HStack(spacing: 4) {
            ForEach(DayType.allCases) { dayType in
                let isSelected = day.dayType == dayType
                Button {
                    Task { await store.setDayType(dayType) }
                } label: {
                    Label(dayType.title, systemImage: dayType.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isSelected ? Color.brand : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today.dayType.\(dayType.rawValue)")
            }
        }
        .padding(4)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private func calorieHero(_ day: DayLog) -> some View {
        let remaining = day.calculated.remainingIntakeKcal
        let eaten = day.totals.caloriesKcal
        let target = day.intakeTargetKcal
        let isOver = remaining < 0
        let fraction = min(max(eaten / max(target, 1), 0), 1)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isOver ? "OVER BUDGET" : "REMAINING")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(abs(remaining), format: .number.precision(.fractionLength(0)))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(isOver ? Color.red : Color.brandDeep)
                            .monospacedDigit()
                        Text("kcal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.brandLeaf)
                    Text("\(eaten.formatted(.number.precision(.fractionLength(0)))) / \(target.formatted(.number.precision(.fractionLength(0))))")
                        .monospacedDigit()
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.brand.opacity(0.14))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isOver ? [.red.opacity(0.8), .red] : [.brandLeaf, .brand],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * fraction))
                }
            }
            .frame(height: 11)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: isOver
                    ? [Color.red.opacity(0.08), Color(.secondarySystemGroupedBackground)]
                    : [Color.brandLeaf.opacity(0.13), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder((isOver ? Color.red : Color.brand).opacity(0.18))
        )
    }

    private func statCards(_ day: DayLog) -> some View {
        HStack(spacing: 10) {
            MetricCard(title: "Eaten", value: day.totals.caloriesKcal, unit: "kcal", systemImage: "fork.knife", tint: .brand)
            MetricCard(title: "Deficit", value: day.calculated.actualDeficitKcal, unit: "kcal", systemImage: "arrow.down.right", tint: .brandLeaf)
            MetricCard(title: "Burn", value: day.burnKcal, unit: "kcal", systemImage: "target", tint: .macroBlue)
        }
    }

    private func macroCard(_ day: DayLog) -> some View {
        VStack(spacing: 14) {
            ProgressMetric(title: "Carbs", value: day.totals.carbsG, target: day.carbsTargetG, unit: "g", systemImage: "laurel.leading", tint: .macroAmber)
            ProgressMetric(title: "Protein", value: day.totals.proteinG, target: day.proteinTargetG, unit: "g", systemImage: "bolt.fill", tint: .brandLeaf)
            ProgressMetric(title: "Fat", value: day.totals.fatG, target: day.fatTargetG, unit: "g", systemImage: "circle.hexagongrid.fill", tint: .macroPlum)
            ProgressMetric(title: "Water", value: day.totals.waterMl, target: day.waterTargetMl, unit: "ml", systemImage: "drop.fill", tint: .macroBlue)
        }
        .card()
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                Task { await store.addWater(250) }
            } label: {
                Label("250 ml", systemImage: "drop")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.macroBlue)

            Button {
                Task { await store.addWater(500) }
            } label: {
                Label("500 ml", systemImage: "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.macroBlue)

            Button {
                sheet = .entry(nil)
            } label: {
                Label("Quick add", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brand)
        }
        .controlSize(.large)
    }

    private var commonFoods: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionLabel(title: "Common foods", systemImage: "bookmark.fill")
                if !store.foodTemplates.isEmpty {
                    Text("\(store.foodTemplates.count)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.brand.opacity(0.12), in: Capsule())
                        .foregroundStyle(.brand)
                }
                Spacer()
                Button {
                    sheet = .template(nil)
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .tint(.brand)
            }

            if store.foodTemplates.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "bookmark")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No common foods yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Save repeated meals to log them in one tap.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.foodTemplates.enumerated()), id: \.element.id) { index, template in
                        foodTemplateRow(template)
                        if index < store.foodTemplates.count - 1 {
                            Divider().padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .card()
    }

    private func foodTemplateRow(_ template: FoodTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: template.mealSlot.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(template.mealSlot.tint)
                    .frame(width: 36, height: 36)
                    .background(template.mealSlot.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(templateMeta(template))
                        .font(.caption2.weight(.semibold))
                        .tracking(0.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Menu {
                    Button {
                        sheet = .template(template)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        templatePendingDelete = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(template.name)")
            }

            HStack(spacing: 6) {
                MacroChip(text: "\(template.caloriesKcal.formatted(.number.precision(.fractionLength(0)))) kcal", isLead: true)
                MacroChip(text: "\(template.proteinG.formatted(.number.precision(.fractionLength(1)))) P")
                MacroChip(text: "\(template.carbsG.formatted(.number.precision(.fractionLength(1)))) C")
                MacroChip(text: "\(template.fatG.formatted(.number.precision(.fractionLength(1)))) F")
            }

            Button {
                Task { await store.logFoodTemplate(template) }
            } label: {
                Label("Log to today", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.brand)
            .accessibilityIdentifier("template.log.\(template.id)")
        }
        .padding(.vertical, 10)
    }

    private func templateMeta(_ template: FoodTemplate) -> String {
        if template.usageCount > 0 {
            return "\(template.mealSlot.title) · \(template.usageCount) logged"
        }
        return template.mealSlot.title
    }

    private func bodyWeight(_ day: DayLog) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "scalemass.fill")
                .font(.title3)
                .foregroundStyle(.brand)
                .frame(width: 42, height: 42)
                .background(Color.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("BODY WEIGHT")
                    .font(.caption2.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(day.bodyWeight.map { $0.weightKg.formatted(.number.precision(.fractionLength(1))) } ?? "--")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text("kg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                sheet = .bodyWeight(day.bodyWeight?.weightKg ?? store.profile?.currentWeightKg ?? 0)
            } label: {
                Label(day.bodyWeight == nil ? "Log" : "Update", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.brand)
        }
        .card()
    }

    private func entries(_ entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title: "Entries", systemImage: "list.bullet.rectangle")
                Spacer()
                Text("\(entries.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.brand.opacity(0.12), in: Capsule())
                    .foregroundStyle(.brand)
            }

            if entries.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No entries yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Use Quick add to log your first meal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        entryRow(entry)
                        if index < entries.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            }
        }
        .card()
    }

    private func entryRow(_ entry: Entry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.mealSlot.systemImage)
                .font(.subheadline)
                .foregroundStyle(entry.mealSlot.tint)
                .frame(width: 36, height: 36)
                .background(entry.mealSlot.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(entry.mealSlot.title)
                    if entry.caloriesKcal > 0 {
                        Text("·")
                        Text("\(entry.caloriesKcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                    }
                    if entry.waterMl > 0 {
                        Text("·")
                        Text("\(entry.waterMl.formatted(.number.precision(.fractionLength(0)))) ml")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                Button {
                    sheet = .entry(entry)
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.brand)
                .accessibilityIdentifier("entry.edit.\(entry.id)")

                Button(role: .destructive) {
                    entryPendingDelete = entry
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("entry.delete.\(entry.id)")
            }
        }
        .padding(.vertical, 8)
    }
}

private enum TodaySheet: Identifiable {
    case entry(Entry?)
    case template(FoodTemplate?)
    case bodyWeight(Double)

    var id: String {
        switch self {
        case .entry(let entry):
            entry?.id ?? "new-entry"
        case .template(let template):
            template?.id ?? "new-template"
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
