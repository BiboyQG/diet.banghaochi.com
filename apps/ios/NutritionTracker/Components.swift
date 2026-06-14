import SwiftUI

struct MetricCard: View {
    let title: String
    let value: Double
    let unit: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value, format: .number.precision(.fractionLength(0)))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ProgressMetric: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String

    private var progress: Double {
        min(max(value / max(target, 1), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.formatted(.number.precision(.fractionLength(0)))) / \(target.formatted(.number.precision(.fractionLength(0)))) \(unit)")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            ProgressView(value: progress)
                .tint(progress > 1 ? .red : .green)
        }
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
    }
}
