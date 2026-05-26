import { serviceClient } from "./supabase-client.ts";

export type Endpoint = "verify-abn" | "verify-licence";

interface Limit {
  bucket: string;       // "user:<uuid>" or "ip:<addr>"
  endpoint: Endpoint;
  maxAttempts: number;
  windowMs: number;     // sliding window length
}

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
}

// Postgres-based sliding window. Cheap enough at expected scale (≤ 25k users).
// At higher volume, swap to Redis/Upstash without changing the call sites.
async function consume(limit: Limit): Promise<RateLimitResult> {
  const db = serviceClient();
  const now = new Date();
  const windowStart = new Date(now.getTime() - limit.windowMs);

  // Count attempts in the live window.
  const { data: rows, error } = await db
    .from("verification_rate_limits")
    .select("attempt_count")
    .eq("bucket_key", limit.bucket)
    .eq("endpoint", limit.endpoint)
    .gte("window_start", windowStart.toISOString());

  if (error) throw error;

  const used = (rows ?? []).reduce((sum, r) => sum + (r.attempt_count ?? 0), 0);
  if (used >= limit.maxAttempts) {
    return {
      allowed: false,
      remaining: 0,
      resetAt: new Date(now.getTime() + limit.windowMs),
    };
  }

  // Record this attempt. window_start is bucketed to the minute so concurrent
  // calls inside the same minute increment a shared row.
  const minuteBucket = new Date(now);
  minuteBucket.setSeconds(0, 0);

  const { error: upsertErr } = await db.rpc("increment_rate_limit", {
    p_bucket_key: limit.bucket,
    p_endpoint: limit.endpoint,
    p_window_start: minuteBucket.toISOString(),
  });

  // If the RPC doesn't exist yet (early dev), fall back to a plain insert.
  if (upsertErr) {
    await db.from("verification_rate_limits").insert({
      bucket_key: limit.bucket,
      endpoint: limit.endpoint,
      window_start: minuteBucket.toISOString(),
      attempt_count: 1,
    });
  }

  return {
    allowed: true,
    remaining: limit.maxAttempts - used - 1,
    resetAt: new Date(now.getTime() + limit.windowMs),
  };
}

export async function checkUserAndIp(
  endpoint: Endpoint,
  userId: string,
  ip: string,
): Promise<RateLimitResult> {
  const userLimit = await consume({
    bucket: `user:${userId}`,
    endpoint,
    maxAttempts: 5,
    windowMs: 60 * 60 * 1000,  // 1 hour
  });
  if (!userLimit.allowed) return userLimit;

  return consume({
    bucket: `ip:${ip}`,
    endpoint,
    maxAttempts: 20,
    windowMs: 60 * 60 * 1000,
  });
}
