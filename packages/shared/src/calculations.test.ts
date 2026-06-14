import { describe, expect, it } from "vitest";
import {
  DEFAULT_PROFILE,
  DEFAULT_TARGETS,
  buildDayFromTemplate,
  calculateActualDeficit,
  calculateBmr,
  calculateMacroCalories,
  calculatePlannedDeficit,
  calculateRemainingIntake,
  calculateRestBurn,
  calculateTrainingBurn,
  copyTargetToDay,
  defaultDayTypeForLocalDate,
  roundKcal,
  shouldWarnMacroCalories,
  sumEntries
} from "./calculations";

describe("nutrition calculations", () => {
  it("uses the Mifflin-St Jeor BMR formula", () => {
    expect(calculateBmr(DEFAULT_PROFILE)).toBe(1642.5);
    expect(roundKcal(calculateBmr(DEFAULT_PROFILE))).toBe(1643);
  });

  it("calculates rest and training day burn", () => {
    expect(roundKcal(calculateRestBurn(DEFAULT_PROFILE))).toBe(1971);
    expect(roundKcal(calculateTrainingBurn(DEFAULT_PROFILE))).toBe(2621);
  });

  it("calculates planned deficit, actual deficit, and remaining intake", () => {
    expect(calculatePlannedDeficit(2620, 2100)).toBe(520);
    expect(calculateActualDeficit(2620, 1800)).toBe(820);
    expect(calculateRemainingIntake(2100, 2200)).toBe(-100);
  });

  it("estimates macro calories and warns on large differences", () => {
    const macros = { carbs_g: 10, protein_g: 20, fat_g: 5 };
    expect(calculateMacroCalories(macros)).toBe(165);
    expect(shouldWarnMacroCalories(600, macros)).toBe(true);
    expect(shouldWarnMacroCalories(180, macros)).toBe(false);
  });

  it("uses the weekly template for day creation", () => {
    expect(defaultDayTypeForLocalDate("2026-06-15")).toBe("training");
    expect(defaultDayTypeForLocalDate("2026-06-16")).toBe("rest");
    expect(buildDayFromTemplate("2026-06-15")).toMatchObject({
      day_type: "training",
      intake_target_kcal: 2100,
      water_target_ml: 3000
    });
  });

  it("copies target values onto a day log", () => {
    const day = copyTargetToDay("2026-06-16", DEFAULT_TARGETS.rest);
    expect(day).toEqual({
      local_date: "2026-06-16",
      day_type: "rest",
      burn_kcal: 1970,
      intake_target_kcal: 1700,
      deficit_target_kcal: 270,
      carbs_target_g: 160,
      protein_target_g: 140,
      fat_target_g: 55,
      water_target_ml: 2300
    });
  });

  it("sums non-deleted entries only", () => {
    expect(
      sumEntries([
        {
          calories_kcal: 500,
          carbs_g: 50,
          protein_g: 30,
          fat_g: 15,
          water_ml: 250
        },
        {
          calories_kcal: 999,
          carbs_g: 999,
          protein_g: 999,
          fat_g: 999,
          water_ml: 999,
          deleted_at: "2026-06-14T00:00:00.000Z"
        }
      ])
    ).toEqual({
      calories_kcal: 500,
      carbs_g: 50,
      protein_g: 30,
      fat_g: 15,
      water_ml: 250
    });
  });
});
