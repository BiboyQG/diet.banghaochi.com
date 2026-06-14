import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import App from "./App";

const today = new Date();
const localDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(
  2,
  "0"
)}-${String(today.getDate()).padStart(2, "0")}`;

function day(entries: unknown[] = []) {
  return {
    id: "day_1",
    local_date: localDate,
    day_type: "training",
    burn_kcal: 2620,
    intake_target_kcal: 2100,
    deficit_target_kcal: 520,
    carbs_target_g: 250,
    protein_target_g: 140,
    fat_target_g: 60,
    water_target_ml: 3000,
    notes: null,
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
    totals: {
      calories_kcal: entries.length === 0 ? 0 : 500,
      carbs_g: entries.length === 0 ? 0 : 40,
      protein_g: entries.length === 0 ? 0 : 30,
      fat_g: entries.length === 0 ? 0 : 12,
      water_ml: entries.length === 0 ? 0 : 250
    },
    calculated: {
      remaining_intake_kcal: entries.length === 0 ? 2100 : 1600,
      actual_deficit_kcal: entries.length === 0 ? 2620 : 2120
    },
    entries,
    body_weight: null
  };
}

function installFetchMock() {
  const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith("/profile")) {
      return json({
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
        created_at: "2026-06-15T00:00:00.000Z",
        updated_at: "2026-06-15T00:00:00.000Z"
      });
    }
    if (url.endsWith("/targets")) {
      return json([
        target("rest", 1970, 1700, 2300),
        target("training", 2620, 2100, 3000)
      ]);
    }
    if (url.includes("/summary")) {
      return json({
        start: localDate,
        end: localDate,
        days: [day()],
        averages: { calories_kcal: 0, protein_g: 0, water_ml: 0 },
        counts: { days: 1, training: 1, rest: 0 },
        estimated_deficit_kcal: 2620
      });
    }
    if (url.includes("/entries") && init?.method === "POST") {
      const entry = {
        id: "entry_1",
        day_log_id: "day_1",
        logged_at: "2026-06-15T12:00:00.000Z",
        meal_slot: "lunch",
        name: "Chicken rice",
        calories_kcal: 500,
        carbs_g: 40,
        protein_g: 30,
        fat_g: 12,
        water_ml: 250,
        notes: null,
        created_at: "2026-06-15T12:00:00.000Z",
        updated_at: "2026-06-15T12:00:00.000Z",
        deleted_at: null
      };
      return json({ entry, day: day([entry]), warnings: [] }, 201);
    }
    if (url.includes("/days/")) return json(day());
    return json({});
  });
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

describe("App", () => {
  it("loads today and submits a manual entry", async () => {
    const fetchMock = installFetchMock();
    render(<App />);

    await screen.findByRole("heading", { name: "Training day" });
    fireEvent.click(screen.getByTestId("today.addEntry"));
    fireEvent.change(screen.getByLabelText("Name"), {
      target: { value: "Chicken rice" }
    });
    fireEvent.change(screen.getByTestId("entry.calories"), {
      target: { value: "500" }
    });
    fireEvent.click(screen.getByTestId("entry.save"));

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledWith(
        "/api/v1/entries",
        expect.objectContaining({ method: "POST" })
      );
    });
  });
});

function target(day_type: string, burn_kcal: number, intake_kcal: number, water_ml: number) {
  return {
    id: `target-${day_type}`,
    day_type,
    burn_kcal,
    intake_kcal,
    deficit_kcal: burn_kcal - intake_kcal,
    carbs_g: 200,
    protein_g: 140,
    fat_g: 60,
    water_ml,
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z"
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" }
  });
}
