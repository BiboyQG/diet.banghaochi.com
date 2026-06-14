import { Hono } from "hono";
import {
  bodyWeightCreateSchema,
  dayPatchSchema,
  dayTypeSchema,
  entryCreateSchema,
  entryPatchSchema,
  localDateSchema,
  profilePatchSchema,
  targetPatchSchema
} from "@diet/shared";
import {
  addBodyWeight,
  createEntry,
  deleteEntry,
  exportAllData,
  getDay,
  getDays,
  getProfile,
  getSummary,
  getTargets,
  patchDay,
  patchEntry,
  patchProfile,
  patchTarget
} from "./db";
import { parseBody, validationError } from "./http";

const app = new Hono<{ Bindings: Env }>();
const defaultIOSCallbackURL = "diettracker://access/callback";

app.onError((error, c) => {
  console.error(
    JSON.stringify({
      message: "unhandled api error",
      error: error.message,
      path: c.req.path
    })
  );
  return c.json({ error: "internal_server_error" }, 500);
});

app.get("/api/v1/health", (c) =>
  c.json({
    status: "ok",
    service: "diet-tracker-api",
    environment: c.env.ENVIRONMENT ?? "unknown"
  })
);

app.get("/auth/ios-callback", (c) =>
  c.redirect(
    iosCallbackURL(
      c.env.IOS_AUTH_CALLBACK_URL ?? defaultIOSCallbackURL,
      c.req.header("cookie")
    )
  )
);

app.get("/api/v1/profile", async (c) => c.json(await getProfile(c.env.DB)));

app.patch("/api/v1/profile", async (c) => {
  const body = await parseBody(c, profilePatchSchema);
  if (!body.ok) return body.response;
  return c.json(await patchProfile(c.env.DB, body.data));
});

app.get("/api/v1/targets", async (c) => c.json(await getTargets(c.env.DB)));

app.patch("/api/v1/targets/:dayType", async (c) => {
  const dayType = dayTypeSchema.safeParse(c.req.param("dayType"));
  if (!dayType.success) return validationError(c, dayType.error);

  const body = await parseBody(c, targetPatchSchema);
  if (!body.ok) return body.response;

  return c.json(await patchTarget(c.env.DB, dayType.data, body.data));
});

app.get("/api/v1/days", async (c) => {
  const start = localDateSchema.safeParse(c.req.query("start"));
  const end = localDateSchema.safeParse(c.req.query("end"));
  if (!start.success) return validationError(c, start.error);
  if (!end.success) return validationError(c, end.error);

  return c.json(await getDays(c.env.DB, start.data, end.data));
});

app.get("/api/v1/days/:localDate", async (c) => {
  const localDate = localDateSchema.safeParse(c.req.param("localDate"));
  if (!localDate.success) return validationError(c, localDate.error);
  return c.json(await getDay(c.env.DB, localDate.data));
});

app.patch("/api/v1/days/:localDate", async (c) => {
  const localDate = localDateSchema.safeParse(c.req.param("localDate"));
  if (!localDate.success) return validationError(c, localDate.error);

  const body = await parseBody(c, dayPatchSchema);
  if (!body.ok) return body.response;

  return c.json(await patchDay(c.env.DB, localDate.data, body.data));
});

app.post("/api/v1/entries", async (c) => {
  const body = await parseBody(c, entryCreateSchema);
  if (!body.ok) return body.response;
  return c.json(await createEntry(c.env.DB, body.data), 201);
});

app.patch("/api/v1/entries/:id", async (c) => {
  const body = await parseBody(c, entryPatchSchema);
  if (!body.ok) return body.response;

  const result = await patchEntry(c.env.DB, c.req.param("id"), body.data);
  if (result == null) return c.json({ error: "not_found" }, 404);

  return c.json(result);
});

app.delete("/api/v1/entries/:id", async (c) => {
  const result = await deleteEntry(c.env.DB, c.req.param("id"));
  if (result == null) return c.json({ error: "not_found" }, 404);
  return c.json(result);
});

app.post("/api/v1/body-weights", async (c) => {
  const body = await parseBody(c, bodyWeightCreateSchema);
  if (!body.ok) return body.response;
  return c.json(await addBodyWeight(c.env.DB, body.data), 201);
});

app.get("/api/v1/summary", async (c) => {
  const start = localDateSchema.safeParse(c.req.query("start"));
  const end = localDateSchema.safeParse(c.req.query("end"));
  if (!start.success) return validationError(c, start.error);
  if (!end.success) return validationError(c, end.error);

  return c.json(await getSummary(c.env.DB, start.data, end.data));
});

app.get("/api/v1/export.json", async (c) => c.json(await exportAllData(c.env.DB)));

function iosCallbackURL(callbackURL: string, cookieHeader: string | undefined) {
  const accessCookie = parseCookies(cookieHeader).CF_Authorization;
  if (accessCookie == null) return callbackURL;

  const callback = new URL(callbackURL);
  callback.searchParams.set("cf_authorization", accessCookie);
  const expiresAt = accessCookieExpiresAt(accessCookie);
  if (expiresAt != null) {
    callback.searchParams.set("expires_at", expiresAt);
  }
  return callback.toString();
}

function parseCookies(cookieHeader: string | undefined) {
  const cookies: Record<string, string> = {};
  for (const part of cookieHeader?.split(";") ?? []) {
    const [name, ...value] = part.trim().split("=");
    if (name != null && name !== "" && value.length > 0) {
      cookies[name] = value.join("=");
    }
  }
  return cookies;
}

function accessCookieExpiresAt(token: string) {
  const payload = token.split(".")[1];
  if (payload == null) return null;

  try {
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(
      base64.length + ((4 - (base64.length % 4)) % 4),
      "="
    );
    const parsed = JSON.parse(atob(padded)) as { exp?: unknown };
    return typeof parsed.exp === "number"
      ? new Date(parsed.exp * 1000).toISOString()
      : null;
  } catch {
    return null;
  }
}

export default app;
