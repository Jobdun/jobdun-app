// POST /functions/v1/verify-licence
//   { licence_number: string, state: AusState, trade_class: string }
//
// Verifies a trade licence against the relevant state regulator's public
// register. Routes through LicenceAdapter implementations — one per state.
//
// Guards: JWT, rate limits, circuit breaker per regulator, audit trail.
// Pre-req: caller must already have a verified kind='abn' row. Otherwise
// returns 412 — Step 1 must succeed before Step 2.

import { jsonResponse, preflight } from "../_shared/cors.ts";
import { clientIp, getUserFromRequest, serviceClient } from "../_shared/supabase-client.ts";
import { checkUserAndIp } from "../_shared/rate-limit.ts";
import { checkBreaker, recordFailure, recordSuccess } from "../_shared/circuit-breaker.ts";
import { adapterFor } from "../_shared/regulators/index.ts";
import { manualFallbackAllowed, type AusState, type LicenceResult } from "../_shared/regulators/types.ts";

interface RequestBody {
  licence_number?: string;
  state?: string;
  trade_class?: string;
}

const AUS_STATES: AusState[] = ["NSW", "VIC", "QLD", "SA", "WA", "TAS", "ACT", "NT"];

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const user = await getUserFromRequest(req);
  if (!user) return jsonResponse({ error: "unauthenticated" }, 401);

  let body: RequestBody;
  try { body = await req.json(); } catch { return jsonResponse({ error: "invalid_json" }, 400); }

  // Phone-verified precondition. Same rationale as verify-abn: regulator
  // lookup confirms the licence exists; it can't prove the human entering
  // it holds it. Phone-verified profile is the cheap-but-real identity
  // anchor. Returned as a structured 200 so the Flutter VerifyResult parser
  // surfaces it as VerifyFailed{ reason: 'phone_required' }.
  const dbForGate = serviceClient();
  const { data: gateProfile } = await dbForGate
    .from("profiles")
    .select("phone_verified_at")
    .eq("id", user.id)
    .maybeSingle();
  if (!gateProfile?.phone_verified_at) {
    return jsonResponse({
      status: "failed",
      reason: "phone_required",
      manual_fallback_allowed: false,
      detail:
        "Verify your phone number first — Profile → Edit → Phone. " +
        "This is required before we mark a licence verified, so Trust & " +
        "Safety has a reachable contact for the attestation.",
    });
  }

  const licenceNumber = (body.licence_number ?? "").trim();
  const state = (body.state ?? "").toUpperCase() as AusState;
  const tradeClass = (body.trade_class ?? "").trim();
  if (!licenceNumber) return jsonResponse({ error: "missing_licence_number" }, 400);
  if (!AUS_STATES.includes(state)) return jsonResponse({ error: "invalid_state" }, 400);
  if (!tradeClass) return jsonResponse({ error: "missing_trade_class" }, 400);

  const adapter = adapterFor(state);
  if (!adapter) return jsonResponse({ error: "state_not_supported", state }, 501);

  const rl = await checkUserAndIp("verify-licence", user.id, clientIp(req));
  if (!rl.allowed) {
    return jsonResponse({ error: "rate_limited", resetAt: rl.resetAt.toISOString() }, 429);
  }

  const db = serviceClient();

  // v2: ABN is NOT required first — verification is optional and per-kind.
  // Tradies can verify ABN, licence, both, or neither, in any order.

  // Upsert one licence row per (user, state, trade_class).
  const { data: existing } = await db
    .from("verifications")
    .select("id")
    .eq("user_id", user.id)
    .eq("kind", "licence")
    .eq("licence_state", state)
    .eq("licence_trade_class", tradeClass)
    .maybeSingle();

  const baseRow = {
    user_id: user.id,
    kind: "licence" as const,
    licence_number: licenceNumber,
    licence_state: state,
    licence_trade_class: tradeClass,
    status: "pending" as const,
    last_checked_at: new Date().toISOString(),
  };

  const { data: row, error: upsertErr } = existing
    ? await db.from("verifications").update(baseRow).eq("id", existing.id).select().single()
    : await db.from("verifications").insert(baseRow).select().single();

  if (upsertErr || !row) {
    return jsonResponse({ error: "db_error", detail: upsertErr?.message ?? "no row" }, 500);
  }

  const breaker = await checkBreaker(state);
  if (breaker.open) {
    await db
      .from("verifications")
      .update({
        status: "manual_review",
        manual_fallback_allowed: true,
        failure_reason: `${state} circuit breaker open`,
      })
      .eq("id", row.id);
    await db.from("manual_verification_requests").insert({
      user_id: user.id,
      verification_id: row.id,
      reason: "circuit_breaker_open",
    });
    return jsonResponse({ status: "manual_review", reason: "regulator_unavailable" });
  }

  let result: LicenceResult;
  const startedAt = Date.now();
  try {
    result = await adapter.verify({ licenceNumber, tradeClass });
  } catch (e) {
    result = {
      status: "unknown",
      detail: `adapter_error: ${(e as Error).message}`,
      raw: null,
    };
  }
  const latencyMs = Date.now() - startedAt;

  await db.from("verification_events").insert({
    verification_id: row.id,
    event_type: "api_call",
    raw_response: { ...(typeof result.raw === "object" ? result.raw : { raw: result.raw }), _meta: { latency_ms: latencyMs, regulator: state } },
  });

  if (result.status === "verified") {
    await recordSuccess(state);
    await db
      .from("verifications")
      .update({
        status: "verified",
        verified_at: new Date().toISOString(),
        expires_at: result.expiresAt?.toISOString() ?? null,
        failure_reason: null,
        manual_fallback_allowed: false,
      })
      .eq("id", row.id);
    return jsonResponse({
      status: "verified",
      holder_name: result.holderName,
      expires_at: result.expiresAt?.toISOString() ?? null,
      regulator_display_name: adapter.regulatorDisplayName,
    });
  }

  if (result.status === "unknown") {
    await recordFailure(state);
    await db
      .from("verifications")
      .update({
        status: "manual_review",
        manual_fallback_allowed: true,
        failure_reason: result.detail,
      })
      .eq("id", row.id);
    await db.from("manual_verification_requests").insert({
      user_id: user.id,
      verification_id: row.id,
      reason: "regulator_unknown_response",
    });
    return jsonResponse({ status: "manual_review", reason: "regulator_unavailable" });
  }

  // status === "failed"
  await recordSuccess(state); // adapter returned a definitive answer — that's a success for the regulator's reachability
  const allowFallback = manualFallbackAllowed(result);
  await db
    .from("verifications")
    .update({
      status: "failed",
      failure_reason: result.detail,
      manual_fallback_allowed: allowFallback,
    })
    .eq("id", row.id);

  return jsonResponse({
    status: "failed",
    reason: result.reason,
    manual_fallback_allowed: allowFallback,
    detail: result.detail,
    regulator_display_name: adapter.regulatorDisplayName,
  });
});
