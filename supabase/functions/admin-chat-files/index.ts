import { createClient } from "npm:@supabase/supabase-js@2.108.2";
import { createBackend } from "./backend.ts";
import { createHandler } from "./handler.ts";
const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !key) throw Error("Staff files configuration missing");
const client = createClient(url, key, {
  auth: { persistSession: false, autoRefreshToken: false },
});
Deno.serve(createHandler(createBackend(client)));
