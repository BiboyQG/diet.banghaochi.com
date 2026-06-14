import type { DayType, MealSlot } from "@diet/shared";

export interface Profile {
  id: string;
  display_name: string;
  email: string;
  sex: "male" | "female";
  age: number;
  height_cm: number;
  current_weight_kg: number;
  timezone: string;
  activity_factor: number;
  training_exercise_kcal: number;
  created_at: string;
  updated_at: string;
}

export interface Target {
  id: string;
  day_type: DayType;
  burn_kcal: number;
  intake_kcal: number;
  deficit_kcal: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  water_ml: number;
  created_at: string;
  updated_at: string;
}

export interface Entry {
  id: string;
  day_log_id: string;
  logged_at: string;
  meal_slot: MealSlot;
  name: string;
  calories_kcal: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  water_ml: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface BodyWeight {
  id: string;
  local_date: string;
  measured_at: string;
  weight_kg: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface DayLog {
  id: string;
  local_date: string;
  day_type: DayType;
  burn_kcal: number;
  intake_target_kcal: number;
  deficit_target_kcal: number;
  carbs_target_g: number;
  protein_target_g: number;
  fat_target_g: number;
  water_target_ml: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
  totals: {
    calories_kcal: number;
    carbs_g: number;
    protein_g: number;
    fat_g: number;
    water_ml: number;
  };
  calculated: {
    remaining_intake_kcal: number;
    actual_deficit_kcal: number;
  };
  entries: Entry[];
  body_weight: BodyWeight | null;
}

export interface Summary {
  start: string;
  end: string;
  days: DayLog[];
  averages: {
    calories_kcal: number;
    protein_g: number;
    water_ml: number;
  };
  counts: {
    days: number;
    training: number;
    rest: number;
  };
  estimated_deficit_kcal: number;
}
