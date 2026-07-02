// F6 (docs/SECURITY_AUDIT_2026-07-02.md): default-deny CORS instead of "*".
// Native mobile clients don't use CORS at all; only browsers (admin web / marketing site) do,
// so we echo an allowlisted Origin and fall back to the primary origin otherwise.
const ALLOWED_ORIGINS = new Set<string>([
  "https://jobdun.com.au",
  "https://www.jobdun.com.au",
  "https://admin.jobdun.com.au",
]);
const DEFAULT_ORIGIN = "https://jobdun.com.au";

export function corsHeaders(origin: string | null = null): Record<string, string> {
  const allow = origin && ALLOWED_ORIGINS.has(origin) ? origin : DEFAULT_ORIGIN;
  return {
    "Access-Control-Allow-Origin": allow,
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

// `origin` is optional so existing callsites (jsonResponse(body, status)) keep working;
// pass req.headers.get("origin") when a browser caller needs its own origin echoed.
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
