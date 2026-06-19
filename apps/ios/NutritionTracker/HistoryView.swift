import SwiftUI

@MainActor
struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var expandedDayId: String?

    var body: some View {
        Group {
            if let summary = store.summary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryCard(summary)
                        trendCard(summary)
                        daysCard(summary)
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView("No history loaded", systemImage: "clock")
                    .task { await store.load() }
            }
        }
        .navigationTitle("History")
        .refreshable {
            await store.load()
        }
    }

    private func summaryCard(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.start) – \(summary.end)".uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.4)
                        .foregroundStyle(.secondary)
                    Text("Two-week summary")
                        .font(.headline)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                countTag("\(summary.counts.training) training", tint: .brand)
                countTag("\(summary.counts.rest) rest", tint: .macroPlum)
                countTag("\(summary.counts.days) logged", tint: .secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                MetricCard(title: "Avg kcal", value: summary.averages.caloriesKcal, unit: "kcal", systemImage: "flame.fill", tint: .brand)
                MetricCard(title: "Avg protein", value: summary.averages.proteinG, unit: "g", systemImage: "bolt.fill", tint: .brandLeaf)
                MetricCard(title: "Avg water", value: summary.averages.waterMl, unit: "ml", systemImage: "drop.fill", tint: .macroBlue)
                MetricCard(title: "Deficit", value: summary.estimatedDeficitKcal, unit: "kcal", systemImage: "arrow.down.right", tint: .macroAmber)
            }
        }
        .card()
        .accessibilityIdentifier("history.summary")
    }

    private func trendCard(_ summary: Summary) -> some View {
        let ordered = Array(summary.days.reversed())
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title: "Kcal and weight", systemImage: "chart.bar.fill")
                Spacer()
                HStack(spacing: 10) {
                    legendDot("Kcal", color: .brand)
                    legendDot("Weight", color: .macroAmber)
                }
            }
            TrendChart(days: ordered)
                .frame(height: 150)
        }
        .card()
    }

    private func daysCard(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Recent logs", systemImage: "calendar")

            if summary.days.isEmpty {
                Text("No logged days yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.days.enumerated()), id: \.element.id) { index, day in
                        dayDisclosure(day)
                        if index < summary.days.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .card()
    }

    private func dayDisclosure(_ day: DayLog) -> some View {
        let isExpanded = expandedDayId == day.id

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    expandedDayId = isExpanded ? nil : day.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: day.dayType.systemImage)
                        .font(.caption)
                        .foregroundStyle(day.dayType == .training ? Color.brand : Color.macroPlum)
                        .frame(width: 32, height: 32)
                        .background((day.dayType == .training ? Color.brand : Color.macroPlum).opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.localDate)
                            .font(.subheadline.weight(.semibold))
                        Text(day.dayType.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(day.totals.caloriesKcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Text("\(day.totals.proteinG.formatted(.number.precision(.fractionLength(0)))) g · \(day.totals.waterMl.formatted(.number.precision(.fractionLength(0)))) ml")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isExpanded ? Color.brand : Color.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .accessibilityIdentifier("history.day.\(day.id)")
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint(isExpanded ? "Double tap to hide this day's details" : "Double tap to show this day's details")

            if isExpanded {
                dayDetails(day)
                    .transition(.opacity)
                    .accessibilityIdentifier("history.details.\(day.id)")
            }
        }
        .clipped()
    }

    private func dayDetails(_ day: DayLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                detailMetric("Carbs", value: day.totals.carbsG, unit: "g")
                detailMetric("Protein", value: day.totals.proteinG, unit: "g")
                detailMetric("Fat", value: day.totals.fatG, unit: "g")
                detailMetric("Water target", value: day.waterTargetMl, unit: "ml")
                detailMetric("Remaining", value: day.calculated.remainingIntakeKcal, unit: "kcal")
                if let weight = day.bodyWeight?.weightKg {
                    detailMetric("Weight", value: weight, unit: "kg")
                } else {
                    detailMetric("Weight", text: "Not logged")
                }
            }

            HStack {
                Text("ENTRIES")
                    .font(.caption2.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(day.entries.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if day.entries.isEmpty {
                Text("No entries logged for this day.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(day.entries) { entry in
                        historyEntryRow(entry)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
        .padding(.bottom, 10)
    }

    private func detailMetric(_ label: String, value: Double, unit: String) -> some View {
        detailMetric(
            label,
            text: "\(value.formatted(.number.precision(.fractionLength(unit == "kg" ? 1 : 0)))) \(unit)"
        )
    }

    private func detailMetric(_ label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.35)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func historyEntryRow(_ entry: Entry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.mealSlot.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.mealSlot.tint)
                .frame(width: 30, height: 30)
                .background(entry.mealSlot.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text("\(entry.mealSlot.title) · \(entry.caloriesKcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.proteinG.formatted(.number.precision(.fractionLength(0)))) g P")
                Text("\(entry.carbsG.formatted(.number.precision(.fractionLength(0)))) g C")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func countTag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.13), in: Capsule())
            .foregroundStyle(tint == .secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
    }

    private func legendDot(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Capsule()
                .fill(color)
                .frame(width: 12, height: 3)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct TrendChart: View {
    let days: [DayLog]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if days.count > 1 {
                    caloriePath(in: size, close: true)
                        .fill(
                            LinearGradient(
                                colors: [Color.brand.opacity(0.22), Color.brand.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    caloriePath(in: size, close: false)
                        .strokedPath(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(.brand)
                }
                weightPath(in: size)
                    .strokedPath(.init(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                    .foregroundStyle(.macroAmber)
            }
        }
    }

    private func caloriePath(in size: CGSize, close: Bool) -> Path {
        let kcal = days.map(\.totals.caloriesKcal)
        let maxKcal = max(kcal.max() ?? 1, 1)
        let stepX = days.count > 1 ? size.width / CGFloat(days.count - 1) : 0
        return Path { path in
            for (i, value) in kcal.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - CGFloat(value / maxKcal) * (size.height * 0.78) - 6
                i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            if close {
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
            }
        }
    }

    private func weightPath(in size: CGSize) -> Path {
        let weights = days.map(\.bodyWeight?.weightKg)
        let known = weights.compactMap { $0 }
        guard known.count > 1 else { return Path() }
        let wMin = known.min() ?? 0
        let wRange = max((known.max() ?? 1) - wMin, 1)
        let stepX = days.count > 1 ? size.width / CGFloat(days.count - 1) : 0
        return Path { path in
            var started = false
            for (i, value) in weights.enumerated() {
                guard let value else { continue }
                let x = CGFloat(i) * stepX
                let y = size.height - CGFloat((value - wMin) / wRange) * (size.height * 0.55) - size.height * 0.18
                if started {
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.move(to: CGPoint(x: x, y: y))
                    started = true
                }
            }
        }
    }
}

#Preview("History") {
    NavigationStack {
        HistoryView()
            .environment(AppStore.previewLoaded)
    }
}
