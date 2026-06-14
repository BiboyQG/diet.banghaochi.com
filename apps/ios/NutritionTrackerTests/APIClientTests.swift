import XCTest
@testable import NutritionTracker

final class APIClientTests: XCTestCase {
    func testSnakeCaseDecodingMatchesWorkerResponses() throws {
        let data = Data(
            """
            {
              "id": "day_1",
              "local_date": "2026-06-14",
              "day_type": "training",
              "burn_kcal": 2620,
              "intake_target_kcal": 2100,
              "deficit_target_kcal": 520,
              "carbs_target_g": 250,
              "protein_target_g": 140,
              "fat_target_g": 60,
              "water_target_ml": 3000,
              "notes": null,
              "created_at": "2026-06-14T00:00:00.000Z",
              "updated_at": "2026-06-14T00:00:00.000Z",
              "totals": {
                "calories_kcal": 600,
                "carbs_g": 65,
                "protein_g": 42,
                "fat_g": 16,
                "water_ml": 250
              },
              "calculated": {
                "remaining_intake_kcal": 1500,
                "actual_deficit_kcal": 2020
              },
              "entries": [],
              "body_weight": null
            }
            """.utf8
        )

        let day = try JSONDecoder.nutrition.decode(DayLog.self, from: data)

        XCTAssertEqual(day.localDate, "2026-06-14")
        XCTAssertEqual(day.dayType, .training)
        XCTAssertEqual(day.totals.proteinG, 42)
        XCTAssertEqual(day.calculated.actualDeficitKcal, 2020)
    }

    func testMockClientCreatesEntryAndUpdatesTotals() async throws {
        let client = NutritionAPIClient.mock(day: .fixture)
        let response = try await client.createEntry(
            EntryCreateRequest(
                localDate: "2026-06-14",
                loggedAt: "2026-06-14T18:00:00.000Z",
                mealSlot: .dinner,
                name: "Salmon",
                caloriesKcal: 500,
                carbsG: 20,
                proteinG: 45,
                fatG: 24,
                waterMl: 0,
                notes: nil
            )
        )

        XCTAssertEqual(response.entry.name, "Salmon")
        XCTAssertEqual(response.day.totals.caloriesKcal, 1100)
        XCTAssertEqual(response.day.entries.first?.name, "Salmon")
    }

    func testMockClientUpdatesAndDeletesEntry() async throws {
        let client = NutritionAPIClient.mock(day: .fixture)

        let updated = try await client.patchEntry(
            Entry.fixture.id,
            EntryPatchRequest(
                loggedAt: nil,
                mealSlot: .dinner,
                name: "Rice bowl",
                caloriesKcal: 450,
                carbsG: 55,
                proteinG: 30,
                fatG: 12,
                waterMl: 0,
                notes: nil
            )
        )

        XCTAssertEqual(updated.entry.name, "Rice bowl")
        XCTAssertEqual(updated.day.totals.caloriesKcal, 450)
        XCTAssertEqual(updated.day.totals.proteinG, 30)

        let deleted = try await client.deleteEntry(Entry.fixture.id)

        XCTAssertEqual(deleted.entry.id, Entry.fixture.id)
        XCTAssertTrue(deleted.day.entries.isEmpty)
        XCTAssertEqual(deleted.day.totals.caloriesKcal, 0)
    }

    func testMockClientAddsBodyWeight() async throws {
        let client = NutritionAPIClient.mock(day: .fixture)
        let bodyWeight = try await client.addBodyWeight(
            BodyWeightCreateRequest(
                localDate: "2026-06-14",
                measuredAt: "2026-06-14T07:00:00.000Z",
                weightKg: 71.2,
                notes: nil
            )
        )

        XCTAssertEqual(bodyWeight.localDate, "2026-06-14")
        XCTAssertEqual(bodyWeight.weightKg, 71.2)
    }

    func testMockClientCreatesAndLogsFoodTemplate() async throws {
        let client = NutritionAPIClient.mock(day: .fixture, foodTemplates: [])

        let template = try await client.createFoodTemplate(
            FoodTemplateCreateRequest(
                mealSlot: .lunch,
                name: "Chipotle bowl",
                caloriesKcal: 540,
                carbsG: 54.5,
                proteinG: 28.5,
                fatG: 20.5,
                waterMl: 0,
                notes: nil
            )
        )
        XCTAssertEqual(template.name, "Chipotle bowl")

        let logged = try await client.logFoodTemplate(
            template.id,
            FoodTemplateLogRequest(
                localDate: "2026-06-14",
                loggedAt: "2026-06-14T18:00:00.000Z",
                mealSlot: nil
            )
        )

        XCTAssertEqual(logged.template.usageCount, 1)
        XCTAssertEqual(logged.entry.name, "Chipotle bowl")
        XCTAssertEqual(logged.day.entries.first?.caloriesKcal, 540)
    }
}
