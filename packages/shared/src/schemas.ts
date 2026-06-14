import { z } from "zod";

export const dayTypeSchema = z.enum(["training", "rest"]);
export const sexSchema = z.enum(["male", "female"]);
export const mealSlotSchema = z.enum([
  "breakfast",
  "lunch",
  "dinner",
  "snack",
  "drink",
  "supplement",
  "other"
]);

export const localDateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Use YYYY-MM-DD.");

export const profilePatchSchema = z
  .object({
    display_name: z.string().min(1).max(120).optional(),
    email: z.string().email().optional(),
    sex: sexSchema.optional(),
    age: z.number().int().min(1).max(130).optional(),
    height_cm: z.number().positive().max(260).optional(),
    current_weight_kg: z.number().positive().max(500).optional(),
    timezone: z.string().min(1).max(80).optional(),
    activity_factor: z.number().positive().max(3).optional(),
    training_exercise_kcal: z.number().nonnegative().max(3000).optional()
  })
  .strict();

export const targetPatchSchema = z
  .object({
    burn_kcal: z.number().nonnegative().max(10000).optional(),
    intake_kcal: z.number().nonnegative().max(10000).optional(),
    deficit_kcal: z.number().min(-10000).max(10000).optional(),
    carbs_g: z.number().nonnegative().max(2000).optional(),
    protein_g: z.number().nonnegative().max(1000).optional(),
    fat_g: z.number().nonnegative().max(1000).optional(),
    water_ml: z.number().nonnegative().max(20000).optional()
  })
  .strict();

export const dayPatchSchema = z
  .object({
    day_type: dayTypeSchema.optional(),
    notes: z.string().max(2000).nullable().optional()
  })
  .strict();

export const entryCreateSchema = z
  .object({
    local_date: localDateSchema,
    logged_at: z.string().datetime().optional(),
    meal_slot: mealSlotSchema,
    name: z.string().min(1).max(160),
    calories_kcal: z.number().nonnegative().max(10000),
    carbs_g: z.number().nonnegative().max(2000),
    protein_g: z.number().nonnegative().max(1000),
    fat_g: z.number().nonnegative().max(1000),
    water_ml: z.number().nonnegative().max(20000),
    notes: z.string().max(2000).nullable().optional()
  })
  .strict();

export const entryPatchSchema = entryCreateSchema
  .omit({ local_date: true })
  .partial()
  .strict();

export const foodTemplateCreateSchema = z
  .object({
    meal_slot: mealSlotSchema,
    name: z.string().min(1).max(160),
    calories_kcal: z.number().nonnegative().max(10000),
    carbs_g: z.number().nonnegative().max(2000),
    protein_g: z.number().nonnegative().max(1000),
    fat_g: z.number().nonnegative().max(1000),
    water_ml: z.number().nonnegative().max(20000),
    notes: z.string().max(2000).nullable().optional()
  })
  .strict();

export const foodTemplatePatchSchema = foodTemplateCreateSchema.partial().strict();

export const foodTemplateLogSchema = z
  .object({
    local_date: localDateSchema,
    logged_at: z.string().datetime().optional(),
    meal_slot: mealSlotSchema.optional()
  })
  .strict();

export const bodyWeightCreateSchema = z
  .object({
    local_date: localDateSchema,
    measured_at: z.string().datetime().optional(),
    weight_kg: z.number().positive().max(500),
    notes: z.string().max(2000).nullable().optional()
  })
  .strict();

export type ProfilePatchInput = z.infer<typeof profilePatchSchema>;
export type TargetPatchInput = z.infer<typeof targetPatchSchema>;
export type DayPatchInput = z.infer<typeof dayPatchSchema>;
export type EntryCreateInput = z.infer<typeof entryCreateSchema>;
export type EntryPatchInput = z.infer<typeof entryPatchSchema>;
export type FoodTemplateCreateInput = z.infer<typeof foodTemplateCreateSchema>;
export type FoodTemplatePatchInput = z.infer<typeof foodTemplatePatchSchema>;
export type FoodTemplateLogInput = z.infer<typeof foodTemplateLogSchema>;
export type BodyWeightCreateInput = z.infer<typeof bodyWeightCreateSchema>;
