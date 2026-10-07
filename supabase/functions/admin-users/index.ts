import { createClient } from "npm:@supabase/supabase-js@2.108.2";
import { createBackend } from "./backend.ts";
import { createHandler, inviteRedirect } from "./handler.ts";

// Privileged credential remains in the Edge environment, never in Next.js.
const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !key) {
  throw new Error("Admin user management configuration missing");
}
const client = createClient(url, key, {
  auth: { persistSession: false, autoRefreshToken: false },
});
Deno.serve(
  createHandler(
    createBackend(client),
    inviteRedirect(Deno.env.get("ADMIN_INVITE_REDIRECT_URL"), url),
  ),
);
