// Shared cache logic for the `jobs-feed` Edge Function. Kept separate from
// index.ts (which calls Deno.serve) so the pure pieces are unit-testable without
// starting a server. Talks to Upstash over its REST API (JSON-array command
// body) — no client dependency, fully curl-verifiable. See
// docs/JOBS_FEED_CACHE_PLAN.md.

import { jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase-client.ts";

export const CACHE_KEY = "jobs:feed:v1:open:p0";
export const STATS_HIT_KEY = "jobs:feed:v1:stats:hit";
export const STATS_MISS_KEY = "jobs:feed:v1:stats:miss";
export const INVALIDATE_LOCK_KEY = "jobs:feed:v1:lock";
export const TTL_SECONDS = 45;
export const INVALIDATE_LOCK_TTL_SECONDS = 5;
export const MAX_LIMIT = 20;

// MUST stay byte-for-byte in sync with `feedColumns` in
// lib/features/jobs/data/datasources/job_remote_datasource.dart — the app parses
// the rows this function returns with JobModel.fromJson, so any drift yields
// nulls or a crash on the client. feed_test.ts asserts this exact string.
export const FEED_COLUMNS =
  "id, builder_id, title, description, suburb, state, postcode, " +
  "trade_type_required, budget_amount, pricing_unit, pricing_type, urgency, " +
  "requires_verified, requires_white_card, application_count, view_count, " +
  "status, published_at, created_at, updated_at, " +
  "latitude, longitude, formatted_address, place_id";

// SECURITY: the client controls only `limit`, and only downward. It can never
// widen the query past one page.
export function clampLimit(requested: unknown): number {
  const n = typeof requested === "number" && Number.isFinite(requested)
    ? Math.floor(requested)
    : MAX_LIMIT;
  return Math.max(1, Math.min(MAX_LIMIT, n));
}

interface RedisReply {
  result?: unknown;
  error?: string;
}

// One Upstash REST call. Never throws — returns { error } on any failure so the
// caller can fall back to origin (the cache must never break the feed).
export async function redis(command: (string | number)[]): Promise<RedisReply> {
  const url = Deno.env.get("UPSTASH_REDIS_REST_URL");
  const token = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");
  if (!url || !token) return { error: "redis_not_configured" };
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(command),
    });
    if (!res.ok) return { error: `redis_http_${res.status}` };
    return await res.json() as RedisReply;
  } catch (e) {
    return { error: `redis_unreachable:${e}` };
  }
}

// Best-effort fire-and-forget: on Supabase Edge keep the instance alive via
// EdgeRuntime.waitUntil; under plain Deno (tests) just swallow errors.
function background(task: Promise<unknown>): void {
  const edge = (globalThis as {
    EdgeRuntime?: { waitUntil(p: Promise<unknown>): void };
  }).EdgeRuntime;
  if (edge?.waitUntil) edge.waitUntil(task.catch(() => {}));
  else task.catch(() => {});
}

async function fetchFeedFromDb(limit: number): Promise<unknown[]> {
  const db = serviceClient();
  // SECURITY: predicate hard-coded to the public feed exactly as RLS policy
  // jobs_select_open allows (status open/filled, not deleted). No client input
  // can change which rows are returned.
  const { data, error } = await db
    .from("jobs")
    .select(FEED_COLUMNS)
    .is("deleted_at", null)
    .in("status", ["open", "filled"])
    .order("published_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data ?? [];
}

export async function handleRead(limit: number): Promise<Response> {
  const cached = await redis(["GET", CACHE_KEY]);

  if (!cached.error && cached.result != null) {
    let jobs: unknown = null;
    try {
      jobs = JSON.parse(cached.result as string);
    } catch {
      jobs = null; // corrupt entry → fall through to origin + repopulate
    }
    if (jobs != null) {
      background(redis(["INCR", STATS_HIT_KEY]));
      return jsonResponse({ source: "cache", jobs });
    }
  }

  const jobs = await fetchFeedFromDb(limit);

  if (cached.error) {
    // Redis not configured / unreachable → serve uncached (kill-switch path).
    return jsonResponse({ source: "origin-no-cache", jobs });
  }

  // Genuine miss → populate (awaited so the cache reliably fills) + count.
  await redis(["SET", CACHE_KEY, JSON.stringify(jobs), "EX", TTL_SECONDS]);
  background(redis(["INCR", STATS_MISS_KEY]));
  return jsonResponse({ source: "origin", jobs });
}

export async function handleInvalidate(): Promise<Response> {
  // Debounce: at most one DEL per INVALIDATE_LOCK_TTL_SECONDS, so a burst of
  // writes (or an abusive caller) can't amplify cache-miss load on Postgres.
  const lock = await redis([
    "SET",
    INVALIDATE_LOCK_KEY,
    "1",
    "NX",
    "EX",
    INVALIDATE_LOCK_TTL_SECONDS,
  ]);
  if (lock.error) {
    return jsonResponse({ invalidated: false, reason: "redis_unavailable" });
  }
  if (lock.result == null) {
    return jsonResponse({ invalidated: false, reason: "debounced" });
  }
  const del = await redis(["DEL", CACHE_KEY]);
  const removed = typeof del.result === "number" ? del.result : 0;
  return jsonResponse({ invalidated: removed > 0 });
}
