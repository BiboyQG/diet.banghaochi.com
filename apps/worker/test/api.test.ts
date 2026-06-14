import { env, exports } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";

const api = exports.default;

beforeEach(async () => {
  const statements = [
    "DROP TABLE IF EXISTS audit_events",
    "DROP TABLE IF EXISTS body_weights",
    "DROP TABLE IF EXISTS food_templates",
    "DROP TABLE IF EXISTS entries",
    "DROP TABLE IF EXISTS day_logs",
    "DROP TABLE IF EXISTS daily_targets",
    "DROP TABLE IF EXISTS profile",
    "CREATE TABLE profile (id TEXT PRIMARY KEY, display_name TEXT NOT NULL, email TEXT NOT NULL UNIQUE, sex TEXT NOT NULL CHECK (sex IN ('male', 'female')), age INTEGER NOT NULL CHECK (age > 0), height_cm REAL NOT NULL CHECK (height_cm > 0), current_weight_kg REAL NOT NULL CHECK (current_weight_kg > 0), timezone TEXT NOT NULL, activity_factor REAL NOT NULL CHECK (activity_factor > 0), training_exercise_kcal INTEGER NOT NULL CHECK (training_exercise_kcal >= 0), created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
    "CREATE TABLE daily_targets (id TEXT PRIMARY KEY, day_type TEXT NOT NULL UNIQUE CHECK (day_type IN ('training', 'rest')), burn_kcal INTEGER NOT NULL CHECK (burn_kcal >= 0), intake_kcal INTEGER NOT NULL CHECK (intake_kcal >= 0), deficit_kcal INTEGER NOT NULL, carbs_g INTEGER NOT NULL CHECK (carbs_g >= 0), protein_g INTEGER NOT NULL CHECK (protein_g >= 0), fat_g INTEGER NOT NULL CHECK (fat_g >= 0), water_ml INTEGER NOT NULL CHECK (water_ml >= 0), created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
    "CREATE TABLE day_logs (id TEXT PRIMARY KEY, local_date TEXT NOT NULL UNIQUE, day_type TEXT NOT NULL CHECK (day_type IN ('training', 'rest')), burn_kcal INTEGER NOT NULL CHECK (burn_kcal >= 0), intake_target_kcal INTEGER NOT NULL CHECK (intake_target_kcal >= 0), deficit_target_kcal INTEGER NOT NULL, carbs_target_g INTEGER NOT NULL CHECK (carbs_target_g >= 0), protein_target_g INTEGER NOT NULL CHECK (protein_target_g >= 0), fat_target_g INTEGER NOT NULL CHECK (fat_target_g >= 0), water_target_ml INTEGER NOT NULL CHECK (water_target_ml >= 0), notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
    "CREATE TABLE entries (id TEXT PRIMARY KEY, day_log_id TEXT NOT NULL REFERENCES day_logs(id) ON DELETE CASCADE, logged_at TEXT NOT NULL, meal_slot TEXT NOT NULL CHECK (meal_slot IN ('breakfast', 'lunch', 'dinner', 'snack', 'drink', 'supplement', 'other')), name TEXT NOT NULL, calories_kcal REAL NOT NULL CHECK (calories_kcal >= 0), carbs_g REAL NOT NULL CHECK (carbs_g >= 0), protein_g REAL NOT NULL CHECK (protein_g >= 0), fat_g REAL NOT NULL CHECK (fat_g >= 0), water_ml REAL NOT NULL CHECK (water_ml >= 0), notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)",
    "CREATE TABLE food_templates (id TEXT PRIMARY KEY, meal_slot TEXT NOT NULL CHECK (meal_slot IN ('breakfast', 'lunch', 'dinner', 'snack', 'drink', 'supplement', 'other')), name TEXT NOT NULL, calories_kcal REAL NOT NULL CHECK (calories_kcal >= 0), carbs_g REAL NOT NULL CHECK (carbs_g >= 0), protein_g REAL NOT NULL CHECK (protein_g >= 0), fat_g REAL NOT NULL CHECK (fat_g >= 0), water_ml REAL NOT NULL CHECK (water_ml >= 0), notes TEXT, usage_count INTEGER NOT NULL DEFAULT 0 CHECK (usage_count >= 0), last_used_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)",
    "CREATE TABLE body_weights (id TEXT PRIMARY KEY, local_date TEXT NOT NULL, measured_at TEXT NOT NULL, weight_kg REAL NOT NULL CHECK (weight_kg > 0), notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
    "CREATE TABLE audit_events (id TEXT PRIMARY KEY, event_type TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, summary TEXT NOT NULL, created_at TEXT NOT NULL)",
    "INSERT INTO profile VALUES ('profile', 'Owner', 'replace-me@example.com', 'male', 25, 170, 70, 'America/Chicago', 1.2, 650, datetime('now'), datetime('now'))",
    "INSERT INTO daily_targets VALUES ('target-training', 'training', 2620, 2100, 520, 250, 140, 60, 3000, datetime('now'), datetime('now'))",
    "INSERT INTO daily_targets VALUES ('target-rest', 'rest', 1970, 1700, 270, 160, 140, 55, 2300, datetime('now'), datetime('now'))"
  ];

  for (const statement of statements) {
    await env.DB.exec(statement);
  }
});

describe("diet tracker api", () => {
  it("returns health status", async () => {
    const response = await api.fetch("http://example.com/api/v1/health");
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ status: "ok" });
  });

  it("redirects iOS auth callback to the app URL scheme", async () => {
    const response = await api.fetch("http://example.com/auth/ios-callback", {
      redirect: "manual"
    });

    expect(response.status).toBe(302);
    expect(response.headers.get("location")).toBe("diettracker://access/callback");
  });

  it("passes the Access cookie through the iOS auth callback", async () => {
    const payload = btoa(JSON.stringify({ exp: 1_700_000_000 }))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/g, "");
    const token = `header.${payload}.signature`;
    const response = await api.fetch("http://example.com/auth/ios-callback", {
      headers: {
        cookie: `CF_Authorization=${token}; CF_AppSession=session`
      },
      redirect: "manual"
    });
    const location = new URL(response.headers.get("location")!);

    expect(response.status).toBe(302);
    expect(location.protocol).toBe("diettracker:");
    expect(location.searchParams.get("cf_authorization")).toBe(token);
    expect(location.searchParams.get("expires_at")).toBe(
      "2023-11-14T22:13:20.000Z"
    );
  });

  it("creates a day from the weekly template", async () => {
    const response = await api.fetch("http://example.com/api/v1/days/2026-06-15");
    const body = await jsonBody<{
      error: string;
      fields: { calories_kcal: string[] };
    }>(response);
    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      local_date: "2026-06-15",
      day_type: "training",
      intake_target_kcal: 2100,
      totals: { calories_kcal: 0 }
    });
  });

  it("returns structured validation errors", async () => {
    const response = await api.fetch("http://example.com/api/v1/entries", {
      method: "POST",
      body: JSON.stringify({
        local_date: "2026-06-15",
        meal_slot: "lunch",
        name: "bad entry",
        calories_kcal: -1,
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        water_ml: 0
      })
    });
    const body = await jsonBody<{
      error: string;
      fields: { calories_kcal: string[] };
    }>(response);
    expect(response.status).toBe(400);
    expect(body).toMatchObject({
      error: "validation_error"
    });
    expect(body.fields.calories_kcal.length).toBeGreaterThan(0);
  });

  it("creates, updates, summarizes, and soft-deletes entries", async () => {
    const createResponse = await api.fetch("http://example.com/api/v1/entries", {
      method: "POST",
      body: JSON.stringify({
        local_date: "2026-06-15",
        logged_at: "2026-06-15T12:00:00.000Z",
        meal_slot: "lunch",
        name: "chicken rice",
        calories_kcal: 600,
        carbs_g: 65,
        protein_g: 42,
        fat_g: 16,
        water_ml: 250
      })
    });
    const created = await jsonBody<{
      entry: { id: string };
      day: { totals: { calories_kcal: number } };
    }>(createResponse);
    expect(createResponse.status).toBe(201);
    expect(created.day.totals.calories_kcal).toBe(600);

    const patchResponse = await api.fetch(
      `http://example.com/api/v1/entries/${created.entry.id}`,
      {
        method: "PATCH",
        body: JSON.stringify({ water_ml: 500 })
      }
    );
    const patched = await jsonBody<{
      day: { totals: { water_ml: number } };
    }>(patchResponse);
    expect(patched.day.totals.water_ml).toBe(500);

    const summaryResponse = await api.fetch(
      "http://example.com/api/v1/summary?start=2026-06-15&end=2026-06-15"
    );
    const summary = await jsonBody<{
      averages: { calories_kcal: number };
      estimated_deficit_kcal: number;
    }>(summaryResponse);
    expect(summary.averages.calories_kcal).toBe(600);
    expect(summary.estimated_deficit_kcal).toBe(2020);

    const deleteResponse = await api.fetch(
      `http://example.com/api/v1/entries/${created.entry.id}`,
      { method: "DELETE" }
    );
    const deleted = await jsonBody<{
      entry: { deleted_at: string | null };
      day: { totals: { calories_kcal: number } };
    }>(deleteResponse);
    expect(deleted.day.totals.calories_kcal).toBe(0);
    expect(deleted.entry.deleted_at).not.toBeNull();
  });

  it("creates, logs, updates, and soft-deletes food templates", async () => {
    const createResponse = await api.fetch(
      "http://example.com/api/v1/food-templates",
      {
        method: "POST",
        body: JSON.stringify({
          meal_slot: "lunch",
          name: "Chipotle bowl",
          calories_kcal: 540,
          carbs_g: 54.5,
          protein_g: 28.5,
          fat_g: 20.5,
          water_ml: 0,
          notes: "No beans"
        })
      }
    );
    const template = await jsonBody<{
      id: string;
      name: string;
      usage_count: number;
    }>(createResponse);

    expect(createResponse.status).toBe(201);
    expect(template.name).toBe("Chipotle bowl");
    expect(template.usage_count).toBe(0);

    const logResponse = await api.fetch(
      `http://example.com/api/v1/food-templates/${template.id}/log`,
      {
        method: "POST",
        body: JSON.stringify({
          local_date: "2026-06-15",
          logged_at: "2026-06-15T12:00:00.000Z"
        })
      }
    );
    const logged = await jsonBody<{
      template: { usage_count: number };
      entry: { name: string; calories_kcal: number };
      day: { totals: { calories_kcal: number; protein_g: number } };
    }>(logResponse);

    expect(logResponse.status).toBe(201);
    expect(logged.template.usage_count).toBe(1);
    expect(logged.entry.name).toBe("Chipotle bowl");
    expect(logged.day.totals.calories_kcal).toBe(540);
    expect(logged.day.totals.protein_g).toBe(28.5);

    const patchResponse = await api.fetch(
      `http://example.com/api/v1/food-templates/${template.id}`,
      {
        method: "PATCH",
        body: JSON.stringify({ name: "Chipotle work bowl" })
      }
    );
    await expect(patchResponse.json()).resolves.toMatchObject({
      name: "Chipotle work bowl"
    });

    const deleteResponse = await api.fetch(
      `http://example.com/api/v1/food-templates/${template.id}`,
      { method: "DELETE" }
    );
    const deleted = await jsonBody<{ deleted_at: string | null }>(deleteResponse);
    expect(deleted.deleted_at).not.toBeNull();

    const listResponse = await api.fetch(
      "http://example.com/api/v1/food-templates"
    );
    await expect(listResponse.json()).resolves.toEqual([]);
  });

  it("updates settings, body weight, and export data", async () => {
    const profileResponse = await api.fetch("http://example.com/api/v1/profile", {
      method: "PATCH",
      body: JSON.stringify({ current_weight_kg: 69.5 })
    });
    await expect(profileResponse.json()).resolves.toMatchObject({
      current_weight_kg: 69.5
    });

    const targetResponse = await api.fetch(
      "http://example.com/api/v1/targets/rest",
      {
        method: "PATCH",
        body: JSON.stringify({ water_ml: 2400 })
      }
    );
    await expect(targetResponse.json()).resolves.toMatchObject({
      day_type: "rest",
      water_ml: 2400
    });

    const weightResponse = await api.fetch(
      "http://example.com/api/v1/body-weights",
      {
        method: "POST",
        body: JSON.stringify({
          local_date: "2026-06-15",
          measured_at: "2026-06-15T07:00:00.000Z",
          weight_kg: 69.5
        })
      }
    );
    expect(weightResponse.status).toBe(201);

    const exportResponse = await api.fetch("http://example.com/api/v1/export.json");
    const exported = await jsonBody<{
      profile: { current_weight_kg: number };
      body_weights: unknown[];
    }>(exportResponse);
    expect(exported.profile.current_weight_kg).toBe(69.5);
    expect(exported.body_weights).toHaveLength(1);
  });
});

async function jsonBody<T>(response: Response): Promise<T> {
  return (await response.json()) as T;
}
