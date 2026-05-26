import { serviceClient } from "./supabase-client.ts";

export type Regulator = "ABR" | "NSW" | "VIC" | "QLD" | "SA" | "WA" | "TAS" | "ACT" | "NT";

const WINDOW_MS = 5 * 60 * 1000;       // 5-minute rolling window
const MIN_CALLS = 10;                   // need at least N calls before tripping
const FAILURE_THRESHOLD = 0.5;          // 50% failures → open
const HALF_OPEN_AFTER_MS = 60 * 1000;   // 60s → half-open probe

export interface BreakerState {
  open: boolean;
  state: "closed" | "open" | "half_open";
}

export async function checkBreaker(reg: Regulator): Promise<BreakerState> {
  const db = serviceClient();
  const { data, error } = await db
    .from("regulator_circuit_state")
    .select("state, opened_at")
    .eq("regulator", reg)
    .single();

  if (error || !data) return { open: false, state: "closed" };

  if (data.state === "open") {
    const openedAt = data.opened_at ? new Date(data.opened_at).getTime() : 0;
    if (Date.now() - openedAt > HALF_OPEN_AFTER_MS) {
      await db
        .from("regulator_circuit_state")
        .update({ state: "half_open", updated_at: new Date().toISOString() })
        .eq("regulator", reg);
      return { open: false, state: "half_open" };
    }
    return { open: true, state: "open" };
  }

  return { open: false, state: data.state as BreakerState["state"] };
}

export async function recordSuccess(reg: Regulator): Promise<void> {
  const db = serviceClient();
  const now = new Date();
  const { data } = await db
    .from("regulator_circuit_state")
    .select("success_count, failure_count, window_started_at, state")
    .eq("regulator", reg)
    .single();

  const windowStart = data?.window_started_at
    ? new Date(data.window_started_at)
    : now;
  const inWindow = now.getTime() - windowStart.getTime() <= WINDOW_MS;

  await db
    .from("regulator_circuit_state")
    .update({
      success_count: inWindow ? (data?.success_count ?? 0) + 1 : 1,
      failure_count: inWindow ? (data?.failure_count ?? 0) : 0,
      window_started_at: inWindow ? windowStart.toISOString() : now.toISOString(),
      state: "closed",
      opened_at: null,
      last_attempt_at: now.toISOString(),
      updated_at: now.toISOString(),
    })
    .eq("regulator", reg);
}

export async function recordFailure(reg: Regulator): Promise<void> {
  const db = serviceClient();
  const now = new Date();
  const { data } = await db
    .from("regulator_circuit_state")
    .select("success_count, failure_count, window_started_at")
    .eq("regulator", reg)
    .single();

  const windowStart = data?.window_started_at
    ? new Date(data.window_started_at)
    : now;
  const inWindow = now.getTime() - windowStart.getTime() <= WINDOW_MS;

  const successes = inWindow ? data?.success_count ?? 0 : 0;
  const failures = (inWindow ? data?.failure_count ?? 0 : 0) + 1;
  const total = successes + failures;

  const shouldOpen =
    total >= MIN_CALLS && failures / total >= FAILURE_THRESHOLD;

  await db
    .from("regulator_circuit_state")
    .update({
      success_count: successes,
      failure_count: failures,
      window_started_at: inWindow ? windowStart.toISOString() : now.toISOString(),
      state: shouldOpen ? "open" : "closed",
      opened_at: shouldOpen ? now.toISOString() : null,
      last_attempt_at: now.toISOString(),
      updated_at: now.toISOString(),
    })
    .eq("regulator", reg);
}
