import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoodDescriptionParserAvailability: Equatable, Sendable {
    case available
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
}

enum FoodDescriptionParserError: LocalizedError {
    case emptyInput
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Describe a food first."
        case .unavailable(let message):
            message
        }
    }
}

struct FoodDescriptionEstimate: Equatable, Sendable {
    var sourceDescription: String
    var name: String
    var servingDescription: String
    var mealSlot: MealSlot
    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var waterMl: Double
    var confidence: Double
    var assumptions: [String]
    var warnings: [String]
}

extension EntryDraft {
    init(estimate: FoodDescriptionEstimate) {
        self.init(
            mealSlot: estimate.mealSlot,
            name: estimate.name,
            caloriesKcal: estimate.caloriesKcal,
            carbsG: estimate.carbsG,
            proteinG: estimate.proteinG,
            fatG: estimate.fatG,
            waterMl: estimate.waterMl,
            notes: estimate.notes
        )
    }
}

private extension FoodDescriptionEstimate {
    var notes: String {
        var lines = ["AI estimate from: \"\(sourceDescription)\""]
        if !servingDescription.isEmpty {
            lines.append("Serving: \(servingDescription)")
        }
        lines.append("Confidence: \((confidence * 100).rounded().formatted(.number.precision(.fractionLength(0))))%")
        if !assumptions.isEmpty {
            lines.append("Assumptions: \(assumptions.joined(separator: "; "))")
        }
        if !warnings.isEmpty {
            lines.append("Warnings: \(warnings.joined(separator: "; "))")
        }
        return lines.joined(separator: "\n")
    }
}

struct FoodDescriptionParser: Sendable {
    private let availabilityCheck: @Sendable () async -> FoodDescriptionParserAvailability
    private let estimateFood: @Sendable (_ description: String) async throws -> FoodDescriptionEstimate

    init(
        availability: @escaping @Sendable () async -> FoodDescriptionParserAvailability,
        estimate: @escaping @Sendable (_ description: String) async throws -> FoodDescriptionEstimate
    ) {
        availabilityCheck = availability
        estimateFood = estimate
    }

    func availability() async -> FoodDescriptionParserAvailability {
        await availabilityCheck()
    }

    func estimate(_ description: String) async throws -> FoodDescriptionEstimate {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FoodDescriptionParserError.emptyInput
        }
        return try await estimateFood(trimmed)
    }

    static var live: FoodDescriptionParser {
        #if canImport(FoundationModels)
        FoodDescriptionParser(
            availability: {
                if #available(iOS 27.0, *) {
                    return FoundationModelsFoodDescriptionParser.availability()
                }
                return .unavailable("AI food estimates require iOS 27 or later.")
            },
            estimate: { description in
                if #available(iOS 27.0, *) {
                    return try await FoundationModelsFoodDescriptionParser().estimate(description)
                }
                throw FoodDescriptionParserError.unavailable("AI food estimates require iOS 27 or later.")
            }
        )
        #else
        FoodDescriptionParser(
            availability: {
                .unavailable("Foundation Models is not available in this build.")
            },
            estimate: { _ in
                throw FoodDescriptionParserError.unavailable("Foundation Models is not available in this build.")
            }
        )
        #endif
    }

    static func mock(
        availability: FoodDescriptionParserAvailability = .available,
        estimate: FoodDescriptionEstimate
    ) -> FoodDescriptionParser {
        FoodDescriptionParser(
            availability: { availability },
            estimate: { description in
                FoodDescriptionEstimate(
                    sourceDescription: description,
                    name: estimate.name,
                    servingDescription: estimate.servingDescription,
                    mealSlot: estimate.mealSlot,
                    caloriesKcal: estimate.caloriesKcal,
                    carbsG: estimate.carbsG,
                    proteinG: estimate.proteinG,
                    fatG: estimate.fatG,
                    waterMl: estimate.waterMl,
                    confidence: estimate.confidence,
                    assumptions: estimate.assumptions,
                    warnings: estimate.warnings
                )
            }
        )
    }
}

#if canImport(FoundationModels)
@available(iOS 27.0, *)
private struct FoundationModelsFoodDescriptionParser {
    static func availability() -> FoodDescriptionParserAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            .available
        case .unavailable(let reason):
            .unavailable(reason.message)
        }
    }

    func estimate(_ description: String) async throws -> FoodDescriptionEstimate {
        let availability = Self.availability()
        guard availability.isAvailable else {
            if case .unavailable(let message) = availability {
                throw FoodDescriptionParserError.unavailable(message)
            }
            throw FoodDescriptionParserError.unavailable("Foundation Models is unavailable.")
        }

        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: """
            You estimate nutrition for a personal diet tracker. Return practical estimates for the described food and serving.
            Prefer common US nutrition assumptions when the user is vague. Do not claim database precision.
            Keep names short and suitable for a food log. Put uncertainty in assumptions and warnings.
            """
        )
        let response = try await session.respond(
            to: """
            Estimate calories, carbohydrates, protein, fat, and water for this food description:
            \(description)
            """,
            generating: GeneratedFoodEstimate.self
        )
        return response.content.estimate(sourceDescription: description)
    }
}

@available(iOS 27.0, *)
@Generable(description: "Estimated nutrition facts for a food log entry.")
private struct GeneratedFoodEstimate {
    @Guide(description: "Short food name suitable for a diet log.")
    var name: String

    @Guide(description: "Serving assumption, such as one large egg or one cooked cup.")
    var servingDescription: String

    @Guide(description: "Meal slot. Use one of: breakfast, lunch, dinner, snack, drink, supplement, other.", .anyOf(MealSlot.allCases.map(\.rawValue)))
    var mealSlot: String

    @Guide(description: "Estimated calories in kcal for the assumed serving.", .range(0...4000))
    var caloriesKcal: Double

    @Guide(description: "Estimated carbohydrates in grams for the assumed serving.", .range(0...600))
    var carbsG: Double

    @Guide(description: "Estimated protein in grams for the assumed serving.", .range(0...300))
    var proteinG: Double

    @Guide(description: "Estimated fat in grams for the assumed serving.", .range(0...300))
    var fatG: Double

    @Guide(description: "Estimated water in milliliters if the item is mainly a drink, otherwise 0.", .range(0...3000))
    var waterMl: Double

    @Guide(description: "Confidence from 0 to 1. Use lower values for vague, mixed, restaurant, or unknown serving descriptions.", .range(0...1))
    var confidence: Double

    @Guide(description: "Brief assumptions used to estimate the nutrition.", .maximumCount(4))
    var assumptions: [String]

    @Guide(description: "Brief caveats the user should review before saving.", .maximumCount(3))
    var warnings: [String]

    func estimate(sourceDescription: String) -> FoodDescriptionEstimate {
        FoodDescriptionEstimate(
            sourceDescription: sourceDescription,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            servingDescription: servingDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            mealSlot: MealSlot(rawValue: mealSlot) ?? .other,
            caloriesKcal: caloriesKcal.clamped(to: 0...4000),
            carbsG: carbsG.clamped(to: 0...600),
            proteinG: proteinG.clamped(to: 0...300),
            fatG: fatG.clamped(to: 0...300),
            waterMl: waterMl.clamped(to: 0...3000),
            confidence: confidence.clamped(to: 0...1),
            assumptions: assumptions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            warnings: warnings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
    }
}

@available(iOS 27.0, *)
private extension SystemLanguageModel.Availability.UnavailableReason {
    var message: String {
        switch self {
        case .deviceNotEligible:
            "This device does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence to use AI food estimates."
        case .modelNotReady:
            "Apple Intelligence is still preparing the on-device model."
        @unknown default:
            "Foundation Models is unavailable."
        }
    }
}
#endif

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard isFinite else {
            return range.lowerBound
        }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
