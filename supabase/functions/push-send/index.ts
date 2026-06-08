// push-send — FCM HTTP v1 sender (#8 push DELIVERY, send side).
//
// Reads device_tokens for the target user(s) and pushes via FCM v1. The in-app
// fan-out (20260609000004) already notifies trades in-app; this adds the actual
// push. Call it from the new-job trigger (pg_net) or a scheduled drain.
//
// REQUIRED env (set as Supabase secrets before this works):
//   FIREBASE_SERVICE_ACCOUNT  — the Firebase *service-account* JSON, single line
//                               (Firebase console → Project settings → Service
//                                accounts → Generate new private key). The ONE
//                               file the Firebase CLI can't mint.
//   FIREBASE_PROJECT_ID       — jobdun-627d2
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY — injected by the platform.
//
// Deploy:
//   supabase functions deploy push-send
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)" \
//     FIREBASE_PROJECT_ID=jobdun-627d2
//
// Body: { "user_ids": ["uuid", ...], "title": "...", "body": "...", "data": {} }

import { createClient } from "jsr:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

Deno.serve(async (req) => {
  try {
    const { user_ids, title, body, data } = await req.json();
    if (!Array.isArray(user_ids) || user_ids.length === 0) {
      return json({ error: "user_ids required" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: rows, error } = await supabase
      .from("device_tokens")
      .select("token")
      .in("user_id", user_ids);
    if (error) return json({ error: error.message }, 500);

    const tokens = (rows ?? []).map((r) => r.token as string);
    if (tokens.length === 0) return json({ sent: 0, total: 0 }, 200);

    const accessToken = await getAccessToken();
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "jobdun-627d2";
    const endpoint =
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    let sent = 0;
    for (const token of tokens) {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: stringifyValues(data ?? {}),
          },
        }),
      });
      if (res.ok) sent++;
      // 404/410 = stale token; a follow-up can prune device_tokens here.
    }
    return json({ sent, total: tokens.length }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

let _auth: GoogleAuth | null = null;
async function getAccessToken(): Promise<string> {
  if (!_auth) {
    const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
    _auth = new GoogleAuth({
      credentials: sa,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
  }
  const client = await _auth.getClient();
  const { token } = await client.getAccessToken();
  if (!token) throw new Error("failed to mint FCM access token");
  return token;
}

// FCM v1 data values must be strings.
function stringifyValues(obj: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(obj)) out[k] = String(v);
  return out;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
