import XCTest
@testable import NutritionTracker

@MainActor
final class FoodDescriptionParserTests: XCTestCase {
    func testEstimateMapsToEditableEntryDraftWithReviewNotes() {
        let estimate = FoodDescriptionEstimate(
            sourceDescription: " two eggs and a banana ",
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

        let draft = EntryDraft(estimate: estimate)

        XCTAssertEqual(draft.mealSlot, .breakfast)
        XCTAssertEqual(draft.name, "Eggs and banana")
        XCTAssertEqual(draft.caloriesKcal, 245)
        XCTAssertEqual(draft.carbsG, 27)
        XCTAssertEqual(draft.proteinG, 13)
        XCTAssertEqual(draft.fatG, 10)
        XCTAssertEqual(draft.waterMl, 0)
        XCTAssertTrue(draft.notes?.contains("AI estimate from") == true)
        XCTAssertTrue(draft.notes?.contains("Confidence: 72%") == true)
        XCTAssertTrue(draft.notes?.contains("Brands and sizes can vary") == true)
    }

    func testMockParserTrimsInputAndPreservesEstimateShape() async throws {
        let parser = FoodDescriptionParser.mock(
            estimate: FoodDescriptionEstimate(
                sourceDescription: "",
                name: "Plain egg",
                servingDescription: "1 large egg",
                mealSlot: .breakfast,
                caloriesKcal: 72,
                carbsG: 0.4,
                proteinG: 6.3,
                fatG: 4.8,
                waterMl: 0,
                confidence: 0.85,
                assumptions: ["Large egg"],
                warnings: []
            )
        )

        let estimate = try await parser.estimate("  egg  ")

        XCTAssertEqual(estimate.sourceDescription, "egg")
        XCTAssertEqual(estimate.name, "Plain egg")
        XCTAssertEqual(estimate.mealSlot, .breakfast)
        XCTAssertEqual(estimate.caloriesKcal, 72)
    }

    func testStoreExposesInjectedFoodDescriptionParser() async throws {
        let store = AppStore(
            client: .mock(),
            foodDescriptionParser: .mock(
                estimate: FoodDescriptionEstimate(
                    sourceDescription: "",
                    name: "Greek yogurt",
                    servingDescription: "1 cup",
                    mealSlot: .snack,
                    caloriesKcal: 150,
                    carbsG: 8,
                    proteinG: 20,
                    fatG: 4,
                    waterMl: 0,
                    confidence: 0.8,
                    assumptions: [],
                    warnings: []
                )
            )
        )

        let availability = await store.foodDescriptionAvailability()
        XCTAssertEqual(availability, .available)

        let estimate = try await store.estimateFoodDescription("greek yogurt")

        XCTAssertEqual(estimate.name, "Greek yogurt")
        XCTAssertEqual(estimate.mealSlot, .snack)
        XCTAssertEqual(estimate.proteinG, 20)
    }

    func testParserRejectsEmptyDescription() async {
        let parser = FoodDescriptionParser.mock(
            estimate: FoodDescriptionEstimate(
                sourceDescription: "",
                name: "Unused",
                servingDescription: "",
                mealSlot: .other,
                caloriesKcal: 0,
                carbsG: 0,
                proteinG: 0,
                fatG: 0,
                waterMl: 0,
                confidence: 0,
                assumptions: [],
                warnings: []
            )
        )

        do {
            _ = try await parser.estimate("  ")
            XCTFail("Expected empty input to fail")
        } catch FoodDescriptionParserError.emptyInput {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
