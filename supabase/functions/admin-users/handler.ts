import { corsHeaders } from "../_shared/cors.ts";

export type UserRole = "builder" | "trade" | "admin";
export interface Backend {
  verifyUser(token: string): Promise<string | null>;
  assertAdmin(actorId: string): Promise<void>;
  consume(
    actorId: string,
    ip: string,
    action: "invite" | "set-role",
  ): Promise<{ allowed: boolean; retryAfter: number }>;
  preflightInvite(actorId: string, email: string): Promise<void>;
  invite(email: string, displayName: string, redirect: string): Promise<string>;
  setRole(
    actorId: string,
    userId: string,
    role: UserRole,
    expectedRole: UserRole | null,
    reason: string,
  ): Promise<{ userId: string; role: UserRole }>;
}
export class DirectoryError extends Error {
  constructor(public code: string, public status: number) {
    super(code);
  }
}
export function inviteRedirect(
  configured: string | undefined,
  supabaseUrl: string | undefined,
): string | null {
  if (!configured || !supabaseUrl) return null;
  try {
    const url = new URL(configured);
    const backend = new URL(supabaseUrl);
    if (url.username || url.password || url.hash) return null;
    const loopback = new Set(["localhost", "127.0.0.1", "[::1]"]);
    const localBackend = backend.protocol === "http:" &&
      (loopback.has(backend.hostname) || backend.hostname === "kong");
    if (
      localBackend && loopback.has(url.hostname) &&
      ["http:", "https:"].includes(url.protocol)
    ) return url.href;
    const approved = new Set([
      "https://admin.jobdun.com.au",
      "https://jobdun.com.au",
      "https://www.jobdun.com.au",
    ]);
    return approved.has(url.origin) ? url.href : null;
  } catch {
    return null;
  }
}

const isRole = (value: unknown): value is UserRole =>
  typeof value === "string" && ["builder", "trade", "admin"].includes(value);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const invalid = () => new DirectoryError("invalid_request", 400);
const hasControl = (value: string) =>
  [...value].some((char) =>
    char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127
  );

async function readBody(request: Request): Promise<Record<string, unknown>> {
  const max = 16384;
  if (Number(request.headers.get("content-length")) > max) {
    throw new DirectoryError("request_too_large", 413);
  }
  if (!request.body) throw invalid();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > max) {
        await reader.cancel();
        throw new DirectoryError("request_too_large", 413);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  try {
    const body = JSON.parse(new TextDecoder().decode(bytes));
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw invalid();
    }
    return body;
  } catch {
    throw invalid();
  }
}

export function createHandler(
  backend: Backend,
  redirect: string | null,
): (request: Request) => Promise<Response> {
  return async (request) => {
    const headers = {
      ...corsHeaders(request.headers.get("origin")),
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Cache-Control": "no-store",
    };
    const json = (body: unknown, status = 200, extra = {}) =>
      new Response(JSON.stringify(body), {
        status,
        headers: { ...headers, "Content-Type": "application/json", ...extra },
      });
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }
    if (!["GET", "POST"].includes(request.method)) {
      return json({ error: "method_not_allowed" }, 405, {
        Allow: "GET, POST, OPTIONS",
      });
    }
    try {
      const token = request.headers.get("authorization")?.match(
        /^Bearer ([^\s]+)$/i,
      )?.[1];
      if (!token) throw new DirectoryError("unauthorized", 401);
      const actor = await backend.verifyUser(token);
      if (!actor) throw new DirectoryError("unauthorized", 401);
      await backend.assertAdmin(actor);
      if (request.method === "GET") {
        return json({ ready: true, invitationConfigured: redirect !== null });
      }
      const body = await readBody(request);
      const { action, role } = body;
      if (!isRole(role)) throw invalid();
      const ip = request.headers.get("cf-connecting-ip") ??
        request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
        "unknown";
      const limit = async (action: "invite" | "set-role") => {
        const result = await backend.consume(actor, ip.slice(0, 200), action);
        return result.allowed ? null : json({ error: "rate_limited" }, 429, {
          "Retry-After": String(result.retryAfter),
        });
      };
      if (action === "invite") {
        if (
          Object.keys(body).some((key) =>
            !["action", "email", "displayName", "role"].includes(key)
          )
        ) throw invalid();
        if (
          typeof body.email !== "string" || typeof body.displayName !== "string"
        ) throw invalid();
        const email = body.email.trim().toLowerCase();
        const name = body.displayName.trim();
        if (
          email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
          hasControl(email) || name.length < 2 || name.length > 100 ||
          hasControl(name)
        ) throw invalid();
        if (!redirect) {
          throw new DirectoryError("invitation_not_configured", 503);
        }
        const denied = await limit("invite");
        if (denied) return denied;
        await backend.preflightInvite(actor, email);
        const userId = await backend.invite(email, name, redirect);
        try {
          await backend.setRole(
            actor,
            userId,
            role,
            null,
            "Admin email invitation",
          );
        } catch {
          // Auth has already sent the email: never report this as an unsent invite.
          return json({
            userId,
            invited: true,
            roleApplied: false,
            error: "role_assignment_failed",
          });
        }
        return json({ userId, invited: true, roleApplied: true });
      }
      if (action === "set-role") {
        if (
          Object.keys(body).some((key) =>
            !["action", "userId", "role", "expectedRole", "reason"].includes(
              key,
            )
          )
        ) throw invalid();
        const { userId, expectedRole } = body;
        if (
          typeof userId !== "string" || !uuid.test(userId) ||
          (expectedRole !== null && !isRole(expectedRole)) ||
          typeof body.reason !== "string"
        ) throw invalid();
        const reason = body.reason.trim();
        if (reason.length < 5 || reason.length > 500 || hasControl(reason)) {
          throw invalid();
        }
        if (userId.toLowerCase() === actor.toLowerCase()) {
          throw new DirectoryError("self_role_change", 409);
        }
        const denied = await limit("set-role");
        if (denied) return denied;
        return json(
          await backend.setRole(
            actor,
            userId.toLowerCase(),
            role,
            expectedRole,
            reason,
          ),
        );
      }
      throw invalid();
    } catch (error) {
      if (error instanceof DirectoryError) {
        return json({ error: error.code }, error.status);
      }
      return json({ error: "unavailable" }, 503);
    }
  };
}
