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
  if (request.method !== "GET") return json({ error: "Method not allowed" }, 405);
  const expected = Deno.env.get("READ_NOTES_SECRET");
  if (!expected || !/^[a-f0-9]{64}$/.test(expected)) {
    return json({ error: "Read endpoint is not configured" }, 503);
  }
  const supplied = request.headers.get("x-read-secret") ?? "";
  if (!/^[a-f0-9]{64}$/.test(supplied) || !await secretsMatch(supplied, expected)) {
    return json({ error: "Unauthorized" }, 401);
  }
  try {
    const projectURL = Deno.env.get("SUPABASE_URL");
    const modernKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
    const key = modernKeys.default ?? Object.values(modernKeys)[0] ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!projectURL || typeof key !== "string") return json({ error: "Server configuration error" }, 503);
    const url = new URL("/rest/v1/notes", projectURL);
    url.searchParams.set("select", "id,body,source,captured_at");
    url.searchParams.set("order", "captured_at.desc,id.desc");
    url.searchParams.set("limit", "100");
    const headers: Record<string, string> = { apikey: key };
    if (!key.startsWith("sb_secret_")) headers.Authorization = `Bearer ${key}`;
    const response = await fetch(url, { headers, signal: AbortSignal.timeout(15000) });
    if (!response.ok) return json({ error: "Unable to read notes" }, 502);
    return json({ notes: await response.json() });
  } catch {
    return json({ error: "Unable to read notes" }, 502);
  }
});
