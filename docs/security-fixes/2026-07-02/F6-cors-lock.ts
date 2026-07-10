// F6 — replace the wildcard CORS in supabase/functions/_shared/cors.ts · API8
//
// Current: a static header object with "Access-Control-Allow-Origin": "*".
// Native mobile clients don't use CORS at all; only browsers (admin web, marketing
// site) do. So scope the header to an origin allowlist and default-deny.
//
// Risk: low. Confirm every real browser origin that legitimately calls these
// functions is in ALLOWED before shipping. NOT applied.

const ALLOWED = new Set<string>([
  "https://jobdun.com.au",
  "https://www.jobdun.com.au",
  "https://admin.jobdun.com.au",
]);

// Build per-request headers (needs the request's Origin).
export function corsHeaders(origin: string | null): Record<string, string> {
  const allow = origin && ALLOWED.has(origin) ? origin : "https://jobdun.com.au";
  return {
    "Access-Control-Allow-Origin": allow,
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

export function jsonResponse(body: unknown, status = 200, origin: string | null = null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req.headers.get("origin")) });
  }
  return null;
}

// CALLER CHANGE: the existing functions call jsonResponse(body, status) and preflight(req).
// Update each callsite that returns a body to pass the origin, e.g.:
//   return jsonResponse({ ok: true }, 200, req.headers.get("origin"));
// preflight() already reads it from the request. Because mobile is native (no Origin
// header), those calls fall through to the safe default — no functional change for the app.
