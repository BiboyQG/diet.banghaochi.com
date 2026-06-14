import SwiftUI

@MainActor
struct HistoryView: View {
    @Environment(AppStore.self) private var store

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
                        dayRow(day)
                        if index < summary.days.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .card()
    }

    private func dayRow(_ day: DayLog) -> some View {
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
        }
        .padding(.vertical, 8)
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
