import {
  type BodyWeightCreateInput,
  type DailyTarget,
  type DayPatchInput,
  type DayType,
  type EntryPatchInput,
  type MealSlot,
  type ProfilePatchInput,
  type TargetPatchInput,
  buildDayFromTemplate,
  calculateActualDeficit,
  calculateRemainingIntake,
  copyTargetToDay,
  shouldWarnMacroCalories,
  sumEntries
} from "@diet/shared";
import type { EntryCreateInput } from "@diet/shared";

type BindValue = string | number | null;

interface ProfileRow {
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

interface TargetRow extends DailyTarget {
  id: string;
  created_at: string;
  updated_at: string;
}

interface DayRow {
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
}

interface EntryRow {
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

interface BodyWeightRow {
  id: string;
  local_date: string;
  measured_at: string;
  weight_kg: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export async function getProfile(db: D1Database): Promise<ProfileRow> {
  const profile = await db
    .prepare("SELECT * FROM profile WHERE id = ?")
    .bind("profile")
    .first<ProfileRow>();
  if (profile == null) {
    throw new Error("profile row is missing");
  }
  return profile;
}

export async function patchProfile(
  db: D1Database,
  input: ProfilePatchInput
): Promise<ProfileRow> {
  const fields: (keyof ProfilePatchInput)[] = [
    "display_name",
    "email",
    "sex",
    "age",
    "height_cm",
    "current_weight_kg",
    "timezone",
    "activity_factor",
    "training_exercise_kcal"
  ];
  const updates: string[] = [];
  const values: BindValue[] = [];

  for (const field of fields) {
    const value = input[field];
    if (value !== undefined) {
      updates.push(`${field} = ?`);
      values.push(value);
    }
  }

  if (updates.length > 0) {
    await db
      .prepare(
        `UPDATE profile SET ${updates.join(", ")}, updated_at = ? WHERE id = ?`
      )
      .bind(...values, nowIso(), "profile")
      .run();
  }

  return getProfile(db);
}

export async function getTargets(db: D1Database): Promise<TargetRow[]> {
  const result = await db
    .prepare("SELECT * FROM daily_targets ORDER BY day_type")
    .all<TargetRow>();
  return result.results;
}

export async function patchTarget(
  db: D1Database,
  dayType: DayType,
  input: TargetPatchInput
): Promise<TargetRow> {
  const fields: (keyof TargetPatchInput)[] = [
    "burn_kcal",
    "intake_kcal",
    "deficit_kcal",
    "carbs_g",
    "protein_g",
    "fat_g",
    "water_ml"
  ];
  const updates: string[] = [];
  const values: BindValue[] = [];

  for (const field of fields) {
    const value = input[field];
    if (value !== undefined) {
      updates.push(`${field} = ?`);
      values.push(value);
    }
  }

  if (updates.length > 0) {
    await db
      .prepare(
        `UPDATE daily_targets SET ${updates.join(
          ", "
        )}, updated_at = ? WHERE day_type = ?`
      )
      .bind(...values, nowIso(), dayType)
      .run();
  }

  const target = await db
    .prepare("SELECT * FROM daily_targets WHERE day_type = ?")
    .bind(dayType)
    .first<TargetRow>();
  if (target == null) {
    throw new Error(`target row is missing for ${dayType}`);
  }
  return target;
}

export async function getDay(db: D1Database, localDate: string) {
  const day = await ensureDay(db, localDate);
  return hydrateDay(db, day);
}

export async function getDays(
  db: D1Database,
  start: string,
  end: string
): Promise<Awaited<ReturnType<typeof hydrateDay>>[]> {
  const result = await db
    .prepare(
      "SELECT * FROM day_logs WHERE local_date BETWEEN ? AND ? ORDER BY local_date DESC"
    )
    .bind(start, end)
    .all<DayRow>();

  const days: Awaited<ReturnType<typeof hydrateDay>>[] = [];
  for (const day of result.results) {
    days.push(await hydrateDay(db, day));
  }
  return days;
}

export async function patchDay(
  db: D1Database,
  localDate: string,
  input: DayPatchInput
) {
  await ensureDay(db, localDate);
  const values: BindValue[] = [];
  const updates: string[] = [];

  if (input.day_type !== undefined) {
    const target = await getTargetRecord(db, input.day_type);
    const copied = copyTargetToDay(localDate, target);
    updates.push(
      "day_type = ?",
      "burn_kcal = ?",
      "intake_target_kcal = ?",
      "deficit_target_kcal = ?",
      "carbs_target_g = ?",
      "protein_target_g = ?",
      "fat_target_g = ?",
      "water_target_ml = ?"
    );
    values.push(
      copied.day_type,
      copied.burn_kcal,
      copied.intake_target_kcal,
      copied.deficit_target_kcal,
      copied.carbs_target_g,
      copied.protein_target_g,
      copied.fat_target_g,
      copied.water_target_ml
    );
  }

  if ("notes" in input) {
    updates.push("notes = ?");
    values.push(input.notes ?? null);
  }

  if (updates.length > 0) {
    await db
      .prepare(
        `UPDATE day_logs SET ${updates.join(
          ", "
        )}, updated_at = ? WHERE local_date = ?`
      )
      .bind(...values, nowIso(), localDate)
      .run();
  }

  return getDay(db, localDate);
}

export async function createEntry(db: D1Database, input: EntryCreateInput) {
  const day = await ensureDay(db, input.local_date);
  const timestamp = nowIso();
  const entryId = id("entry");
  const loggedAt = input.logged_at ?? timestamp;

  await db
    .prepare(
      `INSERT INTO entries (
        id,
        day_log_id,
        logged_at,
        meal_slot,
        name,
        calories_kcal,
        carbs_g,
        protein_g,
        fat_g,
        water_ml,
        notes,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      entryId,
      day.id,
      loggedAt,
      input.meal_slot,
      input.name,
      input.calories_kcal,
      input.carbs_g,
      input.protein_g,
      input.fat_g,
      input.water_ml,
      input.notes ?? null,
      timestamp,
      timestamp
    )
    .run();

  await audit(db, "entry.created", "entry", entryId, input.name);

  return {
    entry: await getEntry(db, entryId),
    day: await getDay(db, input.local_date),
    warnings: entryWarnings(input)
  };
}

export async function patchEntry(
  db: D1Database,
  entryId: string,
  input: EntryPatchInput
) {
  const existing = await getEntry(db, entryId);
  if (existing == null || existing.deleted_at != null) return null;

  const fields: (keyof EntryPatchInput)[] = [
    "logged_at",
    "meal_slot",
    "name",
    "calories_kcal",
    "carbs_g",
    "protein_g",
    "fat_g",
    "water_ml",
    "notes"
  ];
  const updates: string[] = [];
  const values: BindValue[] = [];

  for (const field of fields) {
    if (field in input) {
      updates.push(`${field} = ?`);
      values.push(input[field] ?? null);
    }
  }

  if (updates.length > 0) {
    await db
      .prepare(
        `UPDATE entries SET ${updates.join(", ")}, updated_at = ? WHERE id = ?`
      )
      .bind(...values, nowIso(), entryId)
      .run();
  }

  const entry = await getEntry(db, entryId);
  if (entry == null) return null;
  const day = await dayById(db, entry.day_log_id);
  if (day == null) return null;

  await audit(db, "entry.updated", "entry", entryId, entry.name);

  return {
    entry,
    day: await hydrateDay(db, day),
    warnings: entryWarnings(entry)
  };
}

export async function deleteEntry(db: D1Database, entryId: string) {
  const existing = await getEntry(db, entryId);
  if (existing == null || existing.deleted_at != null) return null;

  const timestamp = nowIso();
  await db
    .prepare("UPDATE entries SET deleted_at = ?, updated_at = ? WHERE id = ?")
    .bind(timestamp, timestamp, entryId)
    .run();

  const day = await dayById(db, existing.day_log_id);
  if (day == null) return null;

  await audit(db, "entry.deleted", "entry", entryId, existing.name);

  return {
    entry: await getEntry(db, entryId),
    day: await hydrateDay(db, day)
  };
}

export async function addBodyWeight(
  db: D1Database,
  input: BodyWeightCreateInput
): Promise<BodyWeightRow> {
  const timestamp = nowIso();
  const bodyWeightId = id("weight");
  await db
    .prepare(
      `INSERT INTO body_weights (
        id,
        local_date,
        measured_at,
        weight_kg,
        notes,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      bodyWeightId,
      input.local_date,
      input.measured_at ?? timestamp,
      input.weight_kg,
      input.notes ?? null,
      timestamp,
      timestamp
    )
    .run();

  await audit(
    db,
    "body_weight.created",
    "body_weight",
    bodyWeightId,
    `${input.weight_kg} kg`
  );

  const row = await db
    .prepare("SELECT * FROM body_weights WHERE id = ?")
    .bind(bodyWeightId)
    .first<BodyWeightRow>();
  if (row == null) throw new Error("body weight insert failed");
  return row;
}

export async function getSummary(db: D1Database, start: string, end: string) {
  const days = await getDays(db, start, end);
  const count = days.length || 1;
  const totalKcal = days.reduce((total, day) => total + day.totals.calories_kcal, 0);
  const totalProtein = days.reduce(
    (total, day) => total + day.totals.protein_g,
    0
  );
  const totalWater = days.reduce((total, day) => total + day.totals.water_ml, 0);
  const estimatedDeficit = days.reduce(
    (total, day) => total + day.calculated.actual_deficit_kcal,
    0
  );

  return {
    start,
    end,
    days,
    averages: {
      calories_kcal: totalKcal / count,
      protein_g: totalProtein / count,
      water_ml: totalWater / count
    },
    counts: {
      days: days.length,
      training: days.filter((day) => day.day_type === "training").length,
      rest: days.filter((day) => day.day_type === "rest").length
    },
    estimated_deficit_kcal: estimatedDeficit
  };
}

export async function exportAllData(db: D1Database) {
  const [profile, targets, days, entries, bodyWeights, auditEvents] =
    await Promise.all([
      getProfile(db),
      getTargets(db),
      db.prepare("SELECT * FROM day_logs ORDER BY local_date").all<DayRow>(),
      db.prepare("SELECT * FROM entries ORDER BY logged_at").all<EntryRow>(),
      db
        .prepare("SELECT * FROM body_weights ORDER BY measured_at")
        .all<BodyWeightRow>(),
      db
        .prepare("SELECT * FROM audit_events ORDER BY created_at")
        .all<Record<string, string>>()
    ]);

  return {
    exported_at: nowIso(),
    profile,
    targets,
    days: days.results,
    entries: entries.results,
    body_weights: bodyWeights.results,
    audit_events: auditEvents.results
  };
}

async function ensureDay(db: D1Database, localDate: string): Promise<DayRow> {
  const existing = await db
    .prepare("SELECT * FROM day_logs WHERE local_date = ?")
    .bind(localDate)
    .first<DayRow>();
  if (existing != null) return existing;

  const targets = await targetRecord(db);
  const template = buildDayFromTemplate(localDate, targets);
  const timestamp = nowIso();
  const dayId = id("day");

  await db
    .prepare(
      `INSERT INTO day_logs (
        id,
        local_date,
        day_type,
        burn_kcal,
        intake_target_kcal,
        deficit_target_kcal,
        carbs_target_g,
        protein_target_g,
        fat_target_g,
        water_target_ml,
        notes,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)`
    )
    .bind(
      dayId,
      template.local_date,
      template.day_type,
      template.burn_kcal,
      template.intake_target_kcal,
      template.deficit_target_kcal,
      template.carbs_target_g,
      template.protein_target_g,
      template.fat_target_g,
      template.water_target_ml,
      timestamp,
      timestamp
    )
    .run();

  await audit(db, "day.created", "day_log", dayId, localDate);

  const created = await db
    .prepare("SELECT * FROM day_logs WHERE id = ?")
    .bind(dayId)
    .first<DayRow>();
  if (created == null) throw new Error("day log insert failed");
  return created;
}

async function hydrateDay(db: D1Database, day: DayRow) {
  const [entriesResult, bodyWeight] = await Promise.all([
    db
      .prepare(
        "SELECT * FROM entries WHERE day_log_id = ? AND deleted_at IS NULL ORDER BY logged_at DESC"
      )
      .bind(day.id)
      .all<EntryRow>(),
    db
      .prepare(
        "SELECT * FROM body_weights WHERE local_date = ? ORDER BY measured_at DESC LIMIT 1"
      )
      .bind(day.local_date)
      .first<BodyWeightRow>()
  ]);
  const totals = sumEntries(entriesResult.results);

  return {
    ...day,
    totals,
    calculated: {
      remaining_intake_kcal: calculateRemainingIntake(
        day.intake_target_kcal,
        totals.calories_kcal
      ),
      actual_deficit_kcal: calculateActualDeficit(
        day.burn_kcal,
        totals.calories_kcal
      )
    },
    entries: entriesResult.results,
    body_weight: bodyWeight
  };
}

async function getEntry(
  db: D1Database,
  entryId: string
): Promise<EntryRow | null> {
  return db
    .prepare("SELECT * FROM entries WHERE id = ?")
    .bind(entryId)
    .first<EntryRow>();
}

async function dayById(db: D1Database, idValue: string): Promise<DayRow | null> {
  return db
    .prepare("SELECT * FROM day_logs WHERE id = ?")
    .bind(idValue)
    .first<DayRow>();
}

async function targetRecord(
  db: D1Database
): Promise<Record<DayType, DailyTarget>> {
  const rows = await getTargets(db);
  const training = rows.find((target) => target.day_type === "training");
  const rest = rows.find((target) => target.day_type === "rest");
  if (training == null || rest == null) {
    throw new Error("daily targets are missing");
  }
  return { training, rest };
}

async function getTargetRecord(
  db: D1Database,
  dayType: DayType
): Promise<TargetRow> {
  const target = await db
    .prepare("SELECT * FROM daily_targets WHERE day_type = ?")
    .bind(dayType)
    .first<TargetRow>();
  if (target == null) {
    throw new Error(`target row is missing for ${dayType}`);
  }
  return target;
}

async function audit(
  db: D1Database,
  eventType: string,
  entityType: string,
  entityId: string,
  summary: string
): Promise<void> {
  await db
    .prepare(
      `INSERT INTO audit_events (
        id,
        event_type,
        entity_type,
        entity_id,
        summary,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?)`
    )
    .bind(id("audit"), eventType, entityType, entityId, summary, nowIso())
    .run();
}

function entryWarnings(entry: {
  calories_kcal: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
}): string[] {
  if (!shouldWarnMacroCalories(entry.calories_kcal, entry)) return [];
  return ["macro_calories_mismatch"];
}

function id(prefix: string): string {
  return `${prefix}_${crypto.randomUUID()}`;
}

function nowIso(): string {
  return new Date().toISOString();
}
