// jobs-feed — shared read-through cache for the public jobs feed.
//
// POST { action?: "read" | "invalidate", limit?: number }
//   read (default) → cached first page of open/filled jobs (Upstash, 45s TTL),
//                    falling back to a direct Postgres read on a miss or if Redis
//                    is unavailable.
//   invalidate     → debounced DEL of the cache key, called after a job write.
//
// Auth: requires a valid Supabase user JWT — the feed is authenticated-only,
// mirroring RLS policy jobs_select_open. See docs/JOBS_FEED_CACHE_PLAN.md.

import { jsonResponse, preflight } from "../_shared/cors.ts";
import { getUserFromRequest } from "../_shared/supabase-client.ts";
import { clampLimit, handleInvalidate, handleRead } from "./feed.ts";

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const user = await getUserFromRequest(req);
  if (!user) return jsonResponse({ error: "unauthenticated" }, 401);

  let body: { action?: string; limit?: number };
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  try {
    if (body.action === "invalidate") return await handleInvalidate();
    return await handleRead(clampLimit(body.limit));
  } catch (e) {
    return jsonResponse({ error: "internal_error", detail: String(e) }, 500);
  }
});
