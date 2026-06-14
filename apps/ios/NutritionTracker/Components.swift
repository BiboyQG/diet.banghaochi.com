import SwiftUI

extension ShapeStyle where Self == Color {
    static var brand: Color { Color(red: 0.12, green: 0.41, blue: 0.29) }
    static var brandDeep: Color { Color(red: 0.09, green: 0.31, blue: 0.22) }
    static var brandLeaf: Color { Color(red: 0.18, green: 0.49, blue: 0.34) }
    static var macroAmber: Color { Color(red: 0.70, green: 0.44, blue: 0.12) }
    static var macroBlue: Color { Color(red: 0.18, green: 0.43, blue: 0.54) }
    static var macroPlum: Color { Color(red: 0.48, green: 0.29, blue: 0.42) }
}

extension MealSlot {
    var systemImage: String {
        switch self {
        case .breakfast: "cup.and.saucer.fill"
        case .lunch: "fork.knife"
        case .dinner: "takeoutbag.and.cup.and.straw.fill"
        case .snack: "birthday.cake.fill"
        case .drink: "waterbottle.fill"
        case .supplement: "pills.fill"
        case .other: "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .breakfast, .snack: .macroAmber
        case .lunch, .supplement, .other: .brandLeaf
        case .dinner: .macroPlum
        case .drink: .macroBlue
        }
    }
}

extension DayType {
    var systemImage: String {
        switch self {
        case .training: "dumbbell.fill"
        case .rest: "moon.stars.fill"
        }
    }
}

private struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05))
            )
    }
}

extension View {
    func card() -> some View {
        modifier(CardSurface())
    }
}

struct SectionLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.brand)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct MacroChip: View {
    let text: String
    var isLead: Bool = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(isLead ? Color.brand : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isLead ? Color.brandLeaf.opacity(0.14) : Color.primary.opacity(0.05),
                in: Capsule()
            )
    }
}

struct MetricCard: View {
    let title: String
    let value: Double
    let unit: String
    var systemImage: String = "circle"
    var tint: Color = .brand

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.4)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value, format: .number.precision(.fractionLength(0)))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        )
    }
}

struct ProgressMetric: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String
    var systemImage: String = "circle.fill"
    var tint: Color = .brand

    private var fraction: Double {
        min(max(value / max(target, 1), 0), 1)
    }

    private var percent: Int {
        Int((value / max(target, 1) * 100).rounded())
    }

    private var isOver: Bool {
        value > target
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(value.formatted(.number.precision(.fractionLength(0)))) / \(target.formatted(.number.precision(.fractionLength(0)))) \(unit)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(isOver ? Color.red : tint)
                            .frame(width: max(6, geo.size.width * fraction))
                    }
                }
                .frame(height: 7)
            }

            Text("\(percent)%")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isOver ? .red : .secondary)
                .frame(width: 42, alignment: .trailing)
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
