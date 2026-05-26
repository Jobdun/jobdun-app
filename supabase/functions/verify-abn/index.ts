// POST /functions/v1/verify-abn   { abn: string }
//
// Verifies an ABN against the Australian Business Register (ABR Web Services).
// Used by BOTH builders (single-step wizard) and trades (Step 1 of two).
//
// Guards:
//   - JWT required (anonymous calls rejected)
//   - Per-user 5/hour + per-IP 20/hour rate limit
//   - Circuit breaker per regulator (ABR)
//   - 3-try retry with exponential backoff + jitter
//   - Audit row in verification_events with raw ABR response
//
// Env: ABR_GUID, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { jsonResponse, preflight } from "../_shared/cors.ts";
import { clientIp, getUserFromRequest, serviceClient } from "../_shared/supabase-client.ts";
import { isValidAbn, normaliseAbn } from "../_shared/abn.ts";
import { checkUserAndIp } from "../_shared/rate-limit.ts";
import { checkBreaker, recordFailure, recordSuccess } from "../_shared/circuit-breaker.ts";
import { fetchWithRetry } from "../_shared/retry.ts";

interface AbrResponse {
  Abn?: string;
  AbnStatus?: string;          // "Active" | "Cancelled"
  EntityName?: string;
  Gst?: string | null;
  Message?: string;
  Exception?: { Code?: string; Description?: string };
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const user = await getUserFromRequest(req);
  if (!user) return jsonResponse({ error: "unauthenticated" }, 401);

  let body: { abn?: string };
  try { body = await req.json(); } catch { return jsonResponse({ error: "invalid_json" }, 400); }

  const abn = normaliseAbn(body.abn ?? "");
  const devMode = Deno.env.get("ABR_DEV_MODE") === "true";
  // Format check (always). Checksum check is strict in prod, skipped in dev
  // mode so any 11-digit string can drive the suffix-routed mock responses.
  if (!/^\d{11}$/.test(abn)) return jsonResponse({ error: "invalid_abn_format" }, 400);
  if (!devMode && !isValidAbn(abn)) return jsonResponse({ error: "invalid_abn_format" }, 400);

  const rl = await checkUserAndIp("verify-abn", user.id, clientIp(req));
  if (!rl.allowed) {
    return jsonResponse(
      { error: "rate_limited", resetAt: rl.resetAt.toISOString() },
      429,
    );
  }

  const db = serviceClient();
  const breaker = await checkBreaker("ABR");

  // Upsert pending row (one verifications row per (user_id, kind=abn))
  const { data: existing } = await db
    .from("verifications")
    .select("id")
    .eq("user_id", user.id)
    .eq("kind", "abn")
    .maybeSingle();

  const baseRow = {
    user_id: user.id,
    kind: "abn" as const,
    abn,
    status: "pending" as const,
    last_checked_at: new Date().toISOString(),
  };

  const { data: row, error: upsertErr } = existing
    ? await db.from("verifications").update(baseRow).eq("id", existing.id).select().single()
    : await db.from("verifications").insert(baseRow).select().single();

  if (upsertErr || !row) {
    return jsonResponse({ error: "db_error", detail: upsertErr?.message ?? "no row" }, 500);
  }

  if (breaker.open) {
    await db
      .from("verifications")
      .update({
        status: "manual_review",
        manual_fallback_allowed: true,
        failure_reason: "ABR circuit breaker open",
      })
      .eq("id", row.id);
    await db.from("manual_verification_requests").insert({
      user_id: user.id,
      verification_id: row.id,
      reason: "circuit_breaker_open",
    });
    return jsonResponse({ status: "manual_review", reason: "regulator_unavailable" });
  }

  const guid = Deno.env.get("ABR_GUID");
  if (!devMode && !guid) return jsonResponse({ error: "abr_not_configured" }, 500);

  let raw: AbrResponse | null = null;
  let abrOk = false;
  const startedAt = Date.now();

  if (devMode) {
    raw = synthesiseAbrResponse(abn);
    abrOk = true;
  } else {
    const url =
      `https://abr.business.gov.au/json/AbnDetails.aspx?abn=${encodeURIComponent(abn)}&guid=${encodeURIComponent(guid!)}`;
    try {
      const res = await fetchWithRetry(url, { method: "GET" }, { tries: 3, baseDelayMs: 1000, factor: 4 });
      // ABR's /json/AbnDetails.aspx always responds with JSONP — Content-Type
      // is text/javascript and the body is wrapped in `callback({...})`,
      // regardless of the callback query param. Strip the wrapper before parse.
      const text = await res.text();
      const match = text.match(/^[a-zA-Z_$][\w$]*\((.*)\)\s*$/s);
      raw = JSON.parse(match ? match[1] : text) as AbrResponse;
      abrOk = res.ok;
    } catch (e) {
      raw = { Message: `fetch_error: ${(e as Error).message}` };
    }
  }
  const latencyMs = Date.now() - startedAt;

  await db.from("verification_events").insert({
    verification_id: row.id,
    event_type: "api_call",
    raw_response: { ...raw, _meta: { latency_ms: latencyMs, regulator: "ABR" } },
  });

  if (!abrOk || !raw) {
    await recordFailure("ABR");
    await db
      .from("verifications")
      .update({
        status: "manual_review",
        manual_fallback_allowed: true,
        failure_reason: "ABR fetch failed",
      })
      .eq("id", row.id);
    await db.from("manual_verification_requests").insert({
      user_id: user.id,
      verification_id: row.id,
      reason: "abr_fetch_failed",
    });
    return jsonResponse({ status: "manual_review", reason: "regulator_unavailable" });
  }

  await recordSuccess("ABR");

  const status = raw.AbnStatus?.toLowerCase();
  if (status === "active") {
    await db
      .from("verifications")
      .update({
        status: "verified",
        abn_entity_name: raw.EntityName ?? null,
        verified_at: new Date().toISOString(),
        failure_reason: null,
        manual_fallback_allowed: false,
      })
      .eq("id", row.id);
    return jsonResponse({
      status: "verified",
      entity_name: raw.EntityName ?? null,
      gst: raw.Gst ?? null,
    });
  }

  // Anything not 'Active' → failed. ABR doesn't suspend, only cancels.
  const reason = status ?? "unknown";
  const allowFallback = !["cancelled", "suspended"].includes(reason);
  await db
    .from("verifications")
    .update({
      status: "failed",
      failure_reason: `ABR status: ${raw.AbnStatus ?? "unknown"}`,
      manual_fallback_allowed: allowFallback,
    })
    .eq("id", row.id);

  return jsonResponse({
    status: "failed",
    reason,
    manual_fallback_allowed: allowFallback,
    detail: `ABR returned status "${raw.AbnStatus ?? "unknown"}"`,
  });
});

// Dev-mode response synthesiser. Mirrors the NSW adapter's suffix routing
// so the Flutter wizard can be exercised before the real ABR GUID lands.
function synthesiseAbrResponse(abn: string): AbrResponse {
  if (abn.endsWith("11111")) {
    return { Abn: abn, AbnStatus: "Cancelled", EntityName: "Cancelled Dev Pty Ltd" };
  }
  if (abn.endsWith("22222")) {
    // ABR doesn't have a "suspended" status, but we model one for symmetry
    // with the licence flow's failure cases.
    return { Abn: abn, AbnStatus: "Suspended", EntityName: "Suspended Dev Pty Ltd" };
  }
  if (abn.endsWith("33333")) {
    return { Abn: abn, AbnStatus: "Unknown", EntityName: "" };
  }
  return {
    Abn: abn,
    AbnStatus: "Active",
    EntityName: `Dev Test Business ${abn.slice(-4)}`,
    Gst: "Active",
  };
}
