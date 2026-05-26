// Retry with exponential backoff + jitter. 3 tries: 1s / 4s / 16s, ±20% jitter.
// Only retries on 5xx / TypeError (network) / DOMException (timeout).

export interface RetryOptions {
  tries?: number;
  baseDelayMs?: number;
  factor?: number;
  jitter?: number;       // 0..1
  timeoutMs?: number;    // per-try timeout
}

export async function fetchWithRetry(
  url: string,
  init: RequestInit = {},
  opts: RetryOptions = {},
): Promise<Response> {
  const tries = opts.tries ?? 3;
  const base = opts.baseDelayMs ?? 1000;
  const factor = opts.factor ?? 4;
  const jitter = opts.jitter ?? 0.2;
  const timeoutMs = opts.timeoutMs ?? 10000;

  let lastErr: unknown;
  for (let attempt = 0; attempt < tries; attempt++) {
    const ac = new AbortController();
    const timeout = setTimeout(() => ac.abort(), timeoutMs);
    try {
      const res = await fetch(url, { ...init, signal: ac.signal });
      clearTimeout(timeout);
      if (res.status < 500) return res;
      lastErr = new Error(`HTTP ${res.status}`);
    } catch (e) {
      clearTimeout(timeout);
      lastErr = e;
    }
    if (attempt < tries - 1) {
      const delay = base * Math.pow(factor, attempt);
      const j = delay * jitter * (Math.random() * 2 - 1);
      await new Promise((r) => setTimeout(r, Math.max(0, delay + j)));
    }
  }
  throw lastErr ?? new Error("fetchWithRetry exhausted");
}
