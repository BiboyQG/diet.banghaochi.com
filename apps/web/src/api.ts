import type {
  BodyWeightCreateInput,
  DayPatchInput,
  EntryCreateInput,
  EntryPatchInput,
  FoodTemplateCreateInput,
  FoodTemplateLogInput,
  FoodTemplatePatchInput,
  ProfilePatchInput,
  TargetPatchInput
} from "@diet/shared";
import type { DayLog, Entry, FoodTemplate, Profile, Summary, Target } from "./types";

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? "/api/v1";

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly details: unknown
  ) {
    super(message);
  }
}

export async function apiRequest<T>(
  path: string,
  init: RequestInit = {}
): Promise<T> {
  const headers = new Headers(init.headers);
  if (init.body != null && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }

  const response = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    throw new ApiError("API request failed", response.status, payload);
  }
  return payload as T;
}

export const api = {
  profile: () => apiRequest<Profile>("/profile"),
  updateProfile: (data: ProfilePatchInput) =>
    apiRequest<Profile>("/profile", {
      method: "PATCH",
      body: JSON.stringify(data)
    }),
  targets: () => apiRequest<Target[]>("/targets"),
  updateTarget: (dayType: string, data: TargetPatchInput) =>
    apiRequest<Target>(`/targets/${dayType}`, {
      method: "PATCH",
      body: JSON.stringify(data)
    }),
  day: (localDate: string) => apiRequest<DayLog>(`/days/${localDate}`),
  updateDay: (localDate: string, data: DayPatchInput) =>
    apiRequest<DayLog>(`/days/${localDate}`, {
      method: "PATCH",
      body: JSON.stringify(data)
    }),
  days: (start: string, end: string) =>
    apiRequest<DayLog[]>(`/days?start=${start}&end=${end}`),
  createEntry: (data: EntryCreateInput) =>
    apiRequest<{ entry: Entry; day: DayLog; warnings: string[] }>("/entries", {
      method: "POST",
      body: JSON.stringify(data)
    }),
  updateEntry: (id: string, data: EntryPatchInput) =>
    apiRequest<{ entry: Entry; day: DayLog; warnings: string[] }>(
      `/entries/${id}`,
      {
        method: "PATCH",
        body: JSON.stringify(data)
      }
    ),
  deleteEntry: (id: string) =>
    apiRequest<{ entry: Entry; day: DayLog }>(`/entries/${id}`, {
      method: "DELETE"
    }),
  foodTemplates: () => apiRequest<FoodTemplate[]>("/food-templates"),
  createFoodTemplate: (data: FoodTemplateCreateInput) =>
    apiRequest<FoodTemplate>("/food-templates", {
      method: "POST",
      body: JSON.stringify(data)
    }),
  updateFoodTemplate: (id: string, data: FoodTemplatePatchInput) =>
    apiRequest<FoodTemplate>(`/food-templates/${id}`, {
      method: "PATCH",
      body: JSON.stringify(data)
    }),
  deleteFoodTemplate: (id: string) =>
    apiRequest<FoodTemplate>(`/food-templates/${id}`, {
      method: "DELETE"
    }),
  logFoodTemplate: (id: string, data: FoodTemplateLogInput) =>
    apiRequest<{
      template: FoodTemplate;
      entry: Entry;
      day: DayLog;
      warnings: string[];
    }>(`/food-templates/${id}/log`, {
      method: "POST",
      body: JSON.stringify(data)
    }),
  addBodyWeight: (data: BodyWeightCreateInput) =>
    apiRequest("/body-weights", {
      method: "POST",
      body: JSON.stringify(data)
    }),
  summary: (start: string, end: string) =>
    apiRequest<Summary>(`/summary?start=${start}&end=${end}`)
};
