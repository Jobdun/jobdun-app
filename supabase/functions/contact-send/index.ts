// POST /functions/v1/contact-send
//   { name, email, message, phone?, role?, state? }
//
// Stores a marketing-site contact enquiry in public.contact_enquiries and,
// when RESEND_API_KEY is configured, emails support@ a copy. Storage is the
// source of truth; email is best-effort notification.
//
// Guards:
//   - x-contact-token must equal the CONTACT_INTERNAL_TOKEN secret, so the
//     ONLY caller is the marketing site's /api/contact route handler (which
//     owns the honeypot + rate limiting). Same pattern as push-send's
//     internal token: the public anon key alone cannot write enquiries.
//   - Field presence + length validation mirrors the DB check constraints,
//     so bad payloads fail fast with a structured error instead of a
//     Postgres exception.
//
// Env: CONTACT_INTERNAL_TOKEN, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
//      RESEND_API_KEY (optional; email disabled when absent)

import { jsonResponse, preflight } from "../_shared/cors.ts";
import { clientIp, serviceClient } from "../_shared/supabase-client.ts";

const SUPPORT_EMAIL = "support@jobdun.com.au";
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

interface ContactPayload {
  name?: unknown;
  email?: unknown;
  phone?: unknown;
  role?: unknown;
  state?: unknown;
  message?: unknown;
}

function asTrimmed(v: unknown, max: number): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim();
  if (t.length === 0 || t.length > max) return null;
  return t;
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Best-effort support email via Resend. Never fails the request. */
async function notifySupport(
  fields: { name: string; email: string; message: string; phone: string | null; role: string | null; state: string | null },
): Promise<void> {
  const key = Deno.env.get("RESEND_API_KEY");
  if (!key) return;
  try {
    const lines = [
      `Name: ${fields.name}`,
      `Email: ${fields.email}`,
      fields.phone ? `Phone: ${fields.phone}` : null,
      fields.role ? `I am a: ${fields.role}` : null,
      fields.state ? `State: ${fields.state}` : null,
      "",
      fields.message,
    ].filter((l): l is string => l !== null);
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `Jobdun contact form <${SUPPORT_EMAIL}>`,
        to: [SUPPORT_EMAIL],
        reply_to: fields.email,
        subject: `Jobdun enquiry from ${fields.name}`,
        text: lines.join("\n"),
      }),
    });
    if (!res.ok) {
      console.error("contact-send: email failed", res.status, await res.text());
    }
  } catch (e) {
    console.error("contact-send: email error", e);
  }
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const expected = Deno.env.get("CONTACT_INTERNAL_TOKEN") ?? "";
  const presented = req.headers.get("x-contact-token") ?? "";
  if (expected.length === 0 || presented !== expected) {
    return jsonResponse({ error: "forbidden" }, 401);
  }

  let body: ContactPayload;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const name = asTrimmed(body.name, 200);
  const email = asTrimmed(body.email, 320);
  const message = asTrimmed(body.message, 5000);
  const phone = asTrimmed(body.phone, 40);
  const role = asTrimmed(body.role, 40);
  const state = asTrimmed(body.state, 10);

  if (!name || !email || !message || !EMAIL_RE.test(email)) {
    return jsonResponse({ error: "invalid_fields" }, 400);
  }

  const supabase = serviceClient();
  const { error } = await supabase.from("contact_enquiries").insert({
    name,
    email,
    phone,
    role,
    state,
    message,
    user_agent: (req.headers.get("user-agent") ?? "").slice(0, 512) || null,
    ip_hash: await sha256Hex(clientIp(req)),
  });
  if (error) {
    console.error("contact-send: insert failed", error);
    return jsonResponse({ error: "storage_failed" }, 500);
  }

  await notifySupport({ name, email, message, phone, role, state });

  return jsonResponse({ ok: true });
});
