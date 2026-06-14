export type DayType = "training" | "rest";
export type Sex = "male" | "female";
export type MealSlot =
  | "breakfast"
  | "lunch"
  | "dinner"
  | "snack"
  | "drink"
  | "supplement"
  | "other";

export interface ProfileAssumptions {
  sex: Sex;
  age: number;
  height_cm: number;
  current_weight_kg: number;
  timezone: string;
  activity_factor: number;
  training_exercise_kcal: number;
}

export interface DailyTarget {
  day_type: DayType;
  burn_kcal: number;
  intake_kcal: number;
  deficit_kcal: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  water_ml: number;
}

export interface MacroInput {
  carbs_g: number;
  protein_g: number;
  fat_g: number;
}

export interface EntryTotals extends MacroInput {
  calories_kcal: number;
  water_ml: number;
}

export interface NutritionEntry extends EntryTotals {
  id?: string;
  meal_slot?: MealSlot;
  deleted_at?: string | null;
}

export interface DayTemplateResult {
  local_date: string;
  day_type: DayType;
  burn_kcal: number;
  intake_target_kcal: number;
  deficit_target_kcal: number;
  carbs_target_g: number;
  protein_target_g: number;
  fat_target_g: number;
  water_target_ml: number;
}

export const DEFAULT_PROFILE: ProfileAssumptions = {
  sex: "male",
  age: 25,
  height_cm: 170,
  current_weight_kg: 70,
  timezone: "America/Chicago",
  activity_factor: 1.2,
  training_exercise_kcal: 650
};

export const DEFAULT_TARGETS: Record<DayType, DailyTarget> = {
  training: {
    day_type: "training",
    burn_kcal: 2620,
    intake_kcal: 2100,
    deficit_kcal: 520,
    carbs_g: 250,
    protein_g: 140,
    fat_g: 60,
    water_ml: 3000
  },
  rest: {
    day_type: "rest",
    burn_kcal: 1970,
    intake_kcal: 1700,
    deficit_kcal: 270,
    carbs_g: 160,
    protein_g: 140,
    fat_g: 55,
    water_ml: 2300
  }
};

const WEEKLY_TEMPLATE: DayType[] = [
  "rest",
  "training",
  "rest",
  "training",
  "rest",
  "training",
  "training"
];

export function calculateBmr(profile: ProfileAssumptions): number {
  const base =
    10 * profile.current_weight_kg + 6.25 * profile.height_cm - 5 * profile.age;
  return profile.sex === "male" ? base + 5 : base - 161;
}

export function calculateRestBurn(profile: ProfileAssumptions): number {
  return calculateBmr(profile) * profile.activity_factor;
}

export function calculateTrainingBurn(profile: ProfileAssumptions): number {
  return calculateRestBurn(profile) + profile.training_exercise_kcal;
}

export function calculatePlannedDeficit(
  burn_kcal: number,
  intake_target_kcal: number
): number {
  return burn_kcal - intake_target_kcal;
}

export function calculateActualDeficit(
  burn_kcal: number,
  consumed_kcal: number
): number {
  return burn_kcal - consumed_kcal;
}

export function calculateRemainingIntake(
  intake_target_kcal: number,
  consumed_kcal: number
): number {
  return intake_target_kcal - consumed_kcal;
}

export function calculateMacroCalories(macros: MacroInput): number {
  return macros.carbs_g * 4 + macros.protein_g * 4 + macros.fat_g * 9;
}

export function shouldWarnMacroCalories(
  calories_kcal: number,
  macros: MacroInput
): boolean {
  const macroCalories = calculateMacroCalories(macros);
  const difference = Math.abs(macroCalories - calories_kcal);
  return difference >= 100 && difference / Math.max(calories_kcal, 1) >= 0.2;
}

export function sumEntries(entries: NutritionEntry[]): EntryTotals {
  return entries
    .filter((entry) => entry.deleted_at == null)
    .reduce<EntryTotals>(
      (totals, entry) => ({
        calories_kcal: totals.calories_kcal + entry.calories_kcal,
        carbs_g: totals.carbs_g + entry.carbs_g,
        protein_g: totals.protein_g + entry.protein_g,
        fat_g: totals.fat_g + entry.fat_g,
        water_ml: totals.water_ml + entry.water_ml
      }),
      {
        calories_kcal: 0,
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        water_ml: 0
      }
    );
}

export function defaultDayTypeForLocalDate(localDate: string): DayType {
  const day = new Date(`${localDate}T00:00:00Z`).getUTCDay();
  return WEEKLY_TEMPLATE[day] ?? "rest";
}

export function targetForDayType(
  dayType: DayType,
  targets: Record<DayType, DailyTarget> = DEFAULT_TARGETS
): DailyTarget {
  return targets[dayType];
}

export function buildDayFromTemplate(
  localDate: string,
  targets: Record<DayType, DailyTarget> = DEFAULT_TARGETS
): DayTemplateResult {
  const dayType = defaultDayTypeForLocalDate(localDate);
  const target = targetForDayType(dayType, targets);
  return copyTargetToDay(localDate, target);
}

export function copyTargetToDay(
  localDate: string,
  target: DailyTarget
): DayTemplateResult {
  return {
    local_date: localDate,
    day_type: target.day_type,
    burn_kcal: target.burn_kcal,
    intake_target_kcal: target.intake_kcal,
    deficit_target_kcal: target.deficit_kcal,
    carbs_target_g: target.carbs_g,
    protein_target_g: target.protein_g,
    fat_target_g: target.fat_g,
    water_target_ml: target.water_ml
  };
}

export function roundKcal(value: number): number {
  return Math.round(value);
}
