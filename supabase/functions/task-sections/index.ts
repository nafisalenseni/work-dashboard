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
  if (!["GET", "POST"].includes(request.method)) return json({ error: "Method not allowed" }, 405);
  const expected = Deno.env.get("READ_NOTES_SECRET");
  if (!expected || !/^[a-f0-9]{64}$/.test(expected)) return json({ error: "Sections endpoint is not configured" }, 503);
  const supplied = request.headers.get("x-read-secret") ?? "";
  if (!/^[a-f0-9]{64}$/.test(supplied) || !await secretsMatch(supplied, expected)) {
    return json({ error: "Unauthorized" }, 401);
  }
  let section: { name: string; color: string } | undefined;
  if (request.method === "POST") {
    let payload;
    try { payload = await request.json(); }
    catch { return json({ error: "Invalid JSON" }, 400); }
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
      return json({ error: "A section name is required" }, 422);
    }
    const name = typeof payload.name === "string" ? payload.name.trim() : "";
    const color = payload.color === undefined ? "yellow" : payload.color;
    if (!name || [...name].length > 80) return json({ error: "Section name must contain 1–80 characters" }, 422);
    if (!["yellow", "red", "green", "blue", "purple", "gray"].includes(color)) {
      return json({ error: "Invalid section color" }, 422);
    }
    section = { name, color };
  }
  try {
    const projectURL = Deno.env.get("SUPABASE_URL");
    const modernKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
    const key = modernKeys.default ?? Object.values(modernKeys)[0] ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!projectURL || typeof key !== "string") return json({ error: "Server configuration error" }, 503);
    const url = new URL("/rest/v1/task_sections", projectURL);
    url.searchParams.set("select", "id,name,color,created_at");
    // Manual ordering stays on the device. The API provides a stable creation order.
    if (request.method === "GET") url.searchParams.set("order", "created_at.asc,id.asc");
    const headers: Record<string, string> = { apikey: key };
    if (!key.startsWith("sb_secret_")) headers.Authorization = `Bearer ${key}`;
    if (section) {
      headers["Content-Type"] = "application/json";
      headers.Prefer = "return=representation";
    }
    const response = await fetch(url, {
      method: request.method, headers,
      body: section ? JSON.stringify(section) : undefined,
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) return json({ error: "Unable to access sections" }, 502);
    const sections = await response.json();
    if (!Array.isArray(sections) || (section && sections.length !== 1)) {
      return json({ error: "Unexpected sections response" }, 502);
    }
    return section ? json({ section: sections[0] }, 201) : json({ sections });
  } catch {
    return json({ error: "Unable to access sections" }, 502);
  }
});
