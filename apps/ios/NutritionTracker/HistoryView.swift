import SwiftUI

@MainActor
struct HistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if let summary = store.summary {
                List {
                    Section("Summary") {
                        LabeledContent("Average kcal", value: summary.averages.caloriesKcal.formatted(.number.precision(.fractionLength(0))))
                        LabeledContent("Average protein", value: "\(summary.averages.proteinG.formatted(.number.precision(.fractionLength(0)))) g")
                        LabeledContent("Average water", value: "\(summary.averages.waterMl.formatted(.number.precision(.fractionLength(0)))) ml")
                        LabeledContent("Estimated deficit", value: "\(summary.estimatedDeficitKcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                    }
                    .accessibilityIdentifier("history.summary")

                    Section("Days") {
                        ForEach(summary.days) { day in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(day.localDate)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(day.dayType.title)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(day.totals.caloriesKcal.formatted(.number.precision(.fractionLength(0)))) kcal · \(day.totals.proteinG.formatted(.number.precision(.fractionLength(0)))) g protein")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    let weights = summary.days.compactMap { day in
                        day.bodyWeight.map { (date: day.localDate, weight: $0.weightKg) }
                    }
                    if !weights.isEmpty {
                        Section("Weight trend") {
                            ForEach(weights, id: \.date) { point in
                                LabeledContent(
                                    point.date,
                                    value: "\(point.weight.formatted(.number.precision(.fractionLength(1)))) kg"
                                )
                            }
                        }
                    }
                }
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
}

#Preview("History") {
    NavigationStack {
        HistoryView()
            .environment(AppStore.previewLoaded)
    }
}
