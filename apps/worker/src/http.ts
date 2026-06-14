import type { Context } from "hono";
import type { ZodError, ZodSchema } from "zod";

type ParseResult<T> =
  | { ok: true; data: T }
  | { ok: false; response: Response };

export async function parseBody<T>(
  c: Context,
  schema: ZodSchema<T>
): Promise<ParseResult<T>> {
  const length = Number(c.req.header("content-length") ?? 0);
  if (length > 32_768) {
    return {
      ok: false,
      response: c.json({ error: "payload_too_large" }, 413)
    };
  }

  let payload: unknown;
  try {
    payload = await c.req.json();
  } catch {
    return {
      ok: false,
      response: c.json({ error: "invalid_json" }, 400)
    };
  }

  const parsed = schema.safeParse(payload);
  if (!parsed.success) {
    return {
      ok: false,
      response: validationError(c, parsed.error)
    };
  }

  return { ok: true, data: parsed.data };
}

export function validationError(c: Context, error: ZodError): Response {
  const fields: Record<string, string[]> = {};
  for (const issue of error.issues) {
    const field = issue.path.join(".") || "_";
    fields[field] = [...(fields[field] ?? []), issue.message];
  }
  return c.json({ error: "validation_error", fields }, 400);
}
