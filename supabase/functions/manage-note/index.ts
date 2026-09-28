// This endpoint is for a single-owner personal inbox. Keep READ_NOTES_SECRET separate
// from CAPTURE_SECRET; neither credential is a Supabase administrator key.
function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}

async function secretsMatch(a: string, b: string): Promise<boolean> {
  const encode = (s: string) => new TextEncoder().encode(s);
  const [left, right] = await Promise.all([a, b].map(s => crypto.subtle.digest("SHA-256", encode(s))));
  const x = new Uint8Array(left), y = new Uint8Array(right);
  let difference = 0;
  for (let i = 0; i < x.length; i++) difference |= x[i] ^ y[i];
  return difference === 0;
}

Deno.serve(async (request: Request) => {
  if (!["PATCH", "DELETE"].includes(request.method)) return json({ error: "Method not allowed" }, 405);
  const expected = Deno.env.get("READ_NOTES_SECRET");
  if (!expected || !/^[a-f0-9]{64}$/.test(expected)) {
    return json({ error: "Inbox endpoint is not configured" }, 503);
  }
  const supplied = request.headers.get("x-read-secret") ?? "";
  if (!/^[a-f0-9]{64}$/.test(supplied) || !await secretsMatch(supplied, expected)) {
    return json({ error: "Unauthorized" }, 401);
  }
  let payload;
  try { payload = await request.json(); }
  catch { return json({ error: "Invalid JSON" }, 400); }
  if (!payload || typeof payload !== "object" ||
      typeof payload.id !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(payload.id)) {
    return json({ error: "A valid note ID is required" }, 422);
  }
  const body = typeof payload.body === "string" ? payload.body.trim() : "";
  if (request.method === "PATCH" && (!body || [...body].length > 10000)) {
    return json({ error: "Note must contain 1–10,000 characters" }, 422);
  }
  try {
    const projectURL = Deno.env.get("SUPABASE_URL");
    const modernKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
    const key = modernKeys.default ?? Object.values(modernKeys)[0] ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!projectURL || typeof key !== "string") return json({ error: "Server configuration error" }, 503);
    const url = new URL("/rest/v1/notes", projectURL);
    url.searchParams.set("select", "id,body,source,captured_at");
    url.searchParams.set("id", `eq.${payload.id}`);
    const headers: Record<string, string> = { apikey: key, "Content-Type": "application/json", Prefer: "return=representation" };
    if (!key.startsWith("sb_secret_")) headers.Authorization = `Bearer ${key}`;
    const response = await fetch(url, {
      method: request.method, headers,
      body: request.method === "PATCH" ? JSON.stringify({ body }) : undefined,
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) return json({ error: "Unable to change note" }, 502);
    const notes = await response.json();
    if (!Array.isArray(notes) || notes.length !== 1) return json({ error: "Note not found" }, 404);
    return json(request.method === "PATCH" ? { note: notes[0] } : { deleted: payload.id });
  } catch {
    return json({ error: "Unable to change note" }, 502);
  }
});
