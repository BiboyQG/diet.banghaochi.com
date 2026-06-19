import { expect, test, type Page, type Route } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await installApiMock(page);
});

test("covers manual logging, history, settings, and responsive layout", async ({
  page
}) => {
  await page.goto("/");

  await expect(page.getByRole("heading", { name: "Training day" })).toBeVisible();
  await expect
    .poll(() =>
      page.evaluate(
        () => document.documentElement.scrollWidth <= document.documentElement.clientWidth
      )
    )
    .toBe(true);

  await page.getByTestId("today.addEntry").click();
  await page.getByLabel("Name").fill("Chicken rice");
  await page.getByTestId("entry.calories").fill("500");
  await page.getByTestId("entry.carbs").fill("40");
  await page.getByTestId("entry.protein").fill("30");
  await page.getByTestId("entry.fat").fill("12");
  await page.getByTestId("entry.water").fill("250");
  await page.getByTestId("entry.save").click();

  await expect(page.getByText("Chicken rice")).toBeVisible();
  await expect(page.getByText("500 kcal")).toBeVisible();

  await page.getByTitle("Edit entry").click();
  await expect(page.getByText("Food entry")).toBeVisible();
  await page.getByLabel("Name").fill("Chicken rice bowl");
  await page.getByTestId("entry.calories").fill("550");
  await page.getByTestId("entry.save").click();

  await expect(page.getByText("Chicken rice bowl")).toBeVisible();
  await expect(page.getByText("550 kcal")).toBeVisible();

  await page.getByTitle("Add 250 ml water").click();
  await expect(page.getByText("500 / 3,000 ml")).toBeVisible();

  await page.getByTestId("today.dayType.rest").click();
  await expect(page.getByRole("heading", { name: "Rest day" })).toBeVisible();
  await expect(page.getByText("1,700 kcal")).toBeVisible();

  page.once("dialog", (dialog) => dialog.accept());
  await page
    .locator("article")
    .filter({ hasText: "Chicken rice bowl" })
    .getByTitle("Delete entry")
    .click();
  await expect(page.getByText("Chicken rice bowl")).toBeHidden();
  await expect(page.getByText("1", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "History" }).click();
  await expect(page.getByTestId("history.summary")).toContainText("rest");
  await expect(page.getByRole("heading", { name: "Kcal and weight" })).toBeVisible();
  await page.getByTestId("history.day.day_1").click();
  await expect(page.getByTestId("history.details.day_1")).toContainText("Water 250 ml");

  await page.getByRole("button", { name: "Settings" }).click();
  const profilePanel = page.locator(".panel").filter({ hasText: "Profile" });
  await profilePanel.getByLabel("Weight kg").fill("69.5");
  await page.getByTestId("settings.profile").click();
  await expect(page.getByText("1638 kcal BMR")).toBeVisible();

  const restTarget = page.locator(".target-row").filter({ hasText: "Rest" });
  await restTarget.getByLabel("Water").fill("2400");
  await restTarget.getByRole("button", { name: "Save" }).click();

  await page.getByRole("button", { name: "Today" }).click();
  await page.getByTestId("today.dayType.training").click();
  await page.getByTestId("today.dayType.rest").click();
  await expect(page.getByText("250 / 2,400 ml")).toBeVisible();

  await page.getByTestId("template.new").click();
  await page.getByTestId("template.name").fill("Chipotle bowl");
  await page.getByTestId("template.calories").fill("540");
  await page.getByTestId("template.carbs").fill("54.5");
  await page.getByTestId("template.protein").fill("28.5");
  await page.getByTestId("template.fat").fill("20.5");
  await page.getByTestId("template.save").click();
  await expect(page.getByText("Chipotle bowl")).toBeVisible();

  await page.getByTitle("Log Chipotle bowl").click();
  await expect(page.locator(".entry-row").filter({ hasText: "Chipotle bowl" })).toContainText(
    "540 kcal"
  );
});

async function installApiMock(page: Page) {
  const state = createApiState();

  await page.route("**/api/v1/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const path = url.pathname.replace(/^\/api\/v1/, "");
    const method = request.method();

    if (method === "GET" && path === "/profile") {
      await fulfill(route, state.profile);
      return;
    }

    if (method === "PATCH" && path === "/profile") {
      state.profile = { ...state.profile, ...(await request.postDataJSON()) };
      await fulfill(route, state.profile);
      return;
    }

    if (method === "GET" && path === "/targets") {
      await fulfill(route, state.targets);
      return;
    }

    if (method === "GET" && path === "/food-templates") {
      await fulfill(route, state.templates);
      return;
    }

    if (method === "POST" && path === "/food-templates") {
      const input = await request.postDataJSON();
      const template = makeTemplate(input, `template_${state.nextTemplateId++}`);
      state.templates = [template, ...state.templates];
      await fulfill(route, template, 201);
      return;
    }

    if (method === "PATCH" && path.startsWith("/food-templates/")) {
      const id = path.split("/").at(-1);
      const patch = await request.postDataJSON();
      state.templates = state.templates.map((template) =>
        template.id === id ? { ...template, ...patch, updated_at: timestamp } : template
      );
      await fulfill(route, state.templates.find((template) => template.id === id));
      return;
    }

    if (method === "DELETE" && path.startsWith("/food-templates/")) {
      const id = path.split("/").at(-1);
      const template = state.templates.find((item) => item.id === id);
      state.templates = state.templates.filter((item) => item.id !== id);
      await fulfill(route, { ...template, deleted_at: timestamp });
      return;
    }

    if (
      method === "POST" &&
      path.startsWith("/food-templates/") &&
      path.endsWith("/log")
    ) {
      const id = path.split("/").at(-2);
      const input = await request.postDataJSON();
      const template = state.templates.find((item) => item.id === id)!;
      const updatedTemplate = {
        ...template,
        usage_count: template.usage_count + 1,
        last_used_at: timestamp,
        updated_at: timestamp
      };
      state.templates = state.templates.map((item) =>
        item.id === id ? updatedTemplate : item
      );
      const entry = makeEntry(
        {
          local_date: input.local_date,
          logged_at: input.logged_at,
          meal_slot: input.meal_slot ?? template.meal_slot,
          name: template.name,
          calories_kcal: template.calories_kcal,
          carbs_g: template.carbs_g,
          protein_g: template.protein_g,
          fat_g: template.fat_g,
          water_ml: template.water_ml,
          notes: template.notes
        },
        `entry_${state.nextEntryId++}`
      );
      state.entries = [entry, ...state.entries];
      await fulfill(
        route,
        { template: updatedTemplate, entry, day: dayResponse(state), warnings: [] },
        201
      );
      return;
    }

    if (method === "PATCH" && path.startsWith("/targets/")) {
      const dayType = path.split("/").at(-1) as DayType;
      const patch = await request.postDataJSON();
      state.targets = state.targets.map((target) =>
        target.day_type === dayType ? { ...target, ...patch } : target
      );
      await fulfill(
        route,
        state.targets.find((target) => target.day_type === dayType)
      );
      return;
    }

    if (method === "GET" && path.startsWith("/days/")) {
      await fulfill(route, dayResponse(state));
      return;
    }

    if (method === "PATCH" && path.startsWith("/days/")) {
      const patch = await request.postDataJSON();
      state.dayType = patch.day_type ?? state.dayType;
      await fulfill(route, dayResponse(state));
      return;
    }

    if (method === "POST" && path === "/entries") {
      const input = await request.postDataJSON();
      const entry = makeEntry(input, `entry_${state.nextEntryId++}`);
      state.entries = [entry, ...state.entries];
      await fulfill(route, { entry, day: dayResponse(state), warnings: [] }, 201);
      return;
    }

    if (method === "PATCH" && path.startsWith("/entries/")) {
      const id = path.split("/").at(-1);
      const patch = await request.postDataJSON();
      state.entries = state.entries.map((entry) =>
        entry.id === id ? { ...entry, ...patch, updated_at: timestamp } : entry
      );
      const entry = state.entries.find((item) => item.id === id);
      await fulfill(route, { entry, day: dayResponse(state), warnings: [] });
      return;
    }

    if (method === "DELETE" && path.startsWith("/entries/")) {
      const id = path.split("/").at(-1);
      const entry = state.entries.find((item) => item.id === id);
      state.entries = state.entries.filter((item) => item.id !== id);
      await fulfill(route, {
        entry: { ...entry, deleted_at: timestamp },
        day: dayResponse(state)
      });
      return;
    }

    if (method === "POST" && path === "/body-weights") {
      const input = await request.postDataJSON();
      state.bodyWeight = {
        id: "weight_1",
        local_date: localDate,
        measured_at: input.measured_at,
        weight_kg: input.weight_kg,
        notes: input.notes,
        created_at: timestamp,
        updated_at: timestamp
      };
      await fulfill(route, state.bodyWeight, 201);
      return;
    }

    if (method === "GET" && path === "/summary") {
      await fulfill(route, summaryResponse(state));
      return;
    }

    throw new Error(`Unhandled API mock route: ${method} ${path}`);
  });
}

function createApiState(): ApiState {
  return {
    profile: {
      id: "profile",
      display_name: "Owner",
      email: "replace-me@example.com",
      sex: "male",
      age: 25,
      height_cm: 170,
      current_weight_kg: 70,
      timezone: "America/Chicago",
      activity_factor: 1.2,
      training_exercise_kcal: 650,
      created_at: timestamp,
      updated_at: timestamp
    },
    targets: [
      target("rest", 1970, 1700, 160, 2300),
      target("training", 2620, 2100, 250, 3000)
    ],
    templates: [],
    dayType: "training",
    entries: [],
    bodyWeight: null,
    nextEntryId: 1,
    nextTemplateId: 1
  };
}

function dayResponse(state: ApiState) {
  const activeTarget = state.targets.find((target) => target.day_type === state.dayType)!;
  const totals = state.entries.reduce(
    (total, entry) => ({
      calories_kcal: total.calories_kcal + entry.calories_kcal,
      carbs_g: total.carbs_g + entry.carbs_g,
      protein_g: total.protein_g + entry.protein_g,
      fat_g: total.fat_g + entry.fat_g,
      water_ml: total.water_ml + entry.water_ml
    }),
    { calories_kcal: 0, carbs_g: 0, protein_g: 0, fat_g: 0, water_ml: 0 }
  );

  return {
    id: "day_1",
    local_date: localDate,
    day_type: state.dayType,
    burn_kcal: activeTarget.burn_kcal,
    intake_target_kcal: activeTarget.intake_kcal,
    deficit_target_kcal: activeTarget.deficit_kcal,
    carbs_target_g: activeTarget.carbs_g,
    protein_target_g: activeTarget.protein_g,
    fat_target_g: activeTarget.fat_g,
    water_target_ml: activeTarget.water_ml,
    notes: null,
    created_at: timestamp,
    updated_at: timestamp,
    totals,
    calculated: {
      remaining_intake_kcal: activeTarget.intake_kcal - totals.calories_kcal,
      actual_deficit_kcal: activeTarget.burn_kcal - totals.calories_kcal
    },
    entries: state.entries,
    body_weight: state.bodyWeight
  };
}

function summaryResponse(state: ApiState) {
  const day = dayResponse(state);
  return {
    start: "2026-06-02",
    end: localDate,
    days: [day],
    averages: {
      calories_kcal: day.totals.calories_kcal,
      protein_g: day.totals.protein_g,
      water_ml: day.totals.water_ml
    },
    counts: {
      days: 1,
      training: day.day_type === "training" ? 1 : 0,
      rest: day.day_type === "rest" ? 1 : 0
    },
    estimated_deficit_kcal: day.calculated.actual_deficit_kcal
  };
}

function makeEntry(input: EntryInput, id: string): Entry {
  return {
    id,
    day_log_id: "day_1",
    logged_at: input.logged_at ?? timestamp,
    meal_slot: input.meal_slot,
    name: input.name,
    calories_kcal: input.calories_kcal,
    carbs_g: input.carbs_g,
    protein_g: input.protein_g,
    fat_g: input.fat_g,
    water_ml: input.water_ml,
    notes: input.notes,
    created_at: timestamp,
    updated_at: timestamp,
    deleted_at: null
  };
}

function makeTemplate(input: EntryInput, id: string): FoodTemplate {
  return {
    id,
    meal_slot: input.meal_slot,
    name: input.name,
    calories_kcal: input.calories_kcal,
    carbs_g: input.carbs_g,
    protein_g: input.protein_g,
    fat_g: input.fat_g,
    water_ml: input.water_ml,
    notes: input.notes,
    usage_count: 0,
    last_used_at: null,
    created_at: timestamp,
    updated_at: timestamp,
    deleted_at: null
  };
}

function target(
  day_type: DayType,
  burn_kcal: number,
  intake_kcal: number,
  carbs_g: number,
  water_ml: number
): Target {
  return {
    id: `target-${day_type}`,
    day_type,
    burn_kcal,
    intake_kcal,
    deficit_kcal: burn_kcal - intake_kcal,
    carbs_g,
    protein_g: 140,
    fat_g: day_type === "training" ? 60 : 55,
    water_ml,
    created_at: timestamp,
    updated_at: timestamp
  };
}

async function fulfill(route: Route, json: unknown, status = 200) {
  await route.fulfill({
    status,
    json,
    headers: { "access-control-allow-origin": "*" }
  });
}

type DayType = "training" | "rest";
type MealSlot =
  | "breakfast"
  | "lunch"
  | "dinner"
  | "snack"
  | "drink"
  | "supplement"
  | "other";

interface ApiState {
  profile: Profile;
  targets: Target[];
  templates: FoodTemplate[];
  dayType: DayType;
  entries: Entry[];
  bodyWeight: BodyWeight | null;
  nextEntryId: number;
  nextTemplateId: number;
}

interface Profile {
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

interface Target {
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

interface EntryInput {
  local_date?: string;
  logged_at?: string;
  meal_slot: MealSlot;
  name: string;
  calories_kcal: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  water_ml: number;
  notes: string | null;
}

interface Entry extends EntryInput {
  id: string;
  day_log_id: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

interface FoodTemplate extends Omit<EntryInput, "logged_at" | "local_date"> {
  id: string;
  usage_count: number;
  last_used_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

interface BodyWeight {
  id: string;
  local_date: string;
  measured_at: string;
  weight_kg: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

const localDate = "2026-06-15";
const timestamp = "2026-06-15T12:00:00.000Z";
