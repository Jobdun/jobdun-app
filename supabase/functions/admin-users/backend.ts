import type { SupabaseClient } from "npm:@supabase/supabase-js@2.108.2";
import { type Backend, DirectoryError } from "./handler.ts";

const statuses: Record<string, number> = {
  not_authorized: 403,
  invalid_request: 400,
  user_not_found: 404,
  self_role_change: 409,
  last_admin: 409,
  role_conflict: 409,
  user_exists: 409,
};
function databaseError(error: { message?: string }): DirectoryError {
  const code = error.message ?? "";
  return Object.hasOwn(statuses, code)
    ? new DirectoryError(code, statuses[code])
    : new DirectoryError("unavailable", 503);
}

export function createBackend(client: SupabaseClient): Backend {
  async function rpc(name: string, args: Record<string, unknown>) {
    const { data, error } = await client.rpc(name, args);
    if (error) throw databaseError(error);
    return data;
  }
  return {
    async verifyUser(token) {
      // Explicit JWT goes only to Auth /user; it does not set this service
      // client's session or change subsequent RPC/invite Authorization.
      const { data, error } = await client.auth.getUser(token);
      if (error || !data.user) return null;
      return data.user.id;
    },
    async assertAdmin(actorId) {
      if (
        await rpc("admin_user_management_ready", { p_actor_id: actorId }) !==
          true
      ) throw new DirectoryError("unavailable", 503);
    },
    async consume(actorId, ip, action) {
      const result = await rpc("admin_user_management_rate_limit", {
        p_actor_id: actorId,
        p_ip: ip,
        p_action: action,
      });
      if (
        typeof result?.allowed !== "boolean" ||
        !Number.isInteger(result?.retry_after) || result.retry_after < 1
      ) throw new DirectoryError("unavailable", 503);
      return { allowed: result.allowed, retryAfter: result.retry_after };
    },
    async preflightInvite(actorId, email) {
      await rpc("admin_user_invitation_preflight", {
        p_actor_id: actorId,
        p_email: email,
      });
    },
    async invite(email, displayName, redirect) {
      const { data, error } = await client.auth.admin.inviteUserByEmail(email, {
        // Do not put role in user-editable metadata. The atomic RPC assigns it.
        data: { full_name: displayName },
        redirectTo: redirect,
      });
      if (error) {
        if (
          ["email_exists", "user_already_exists"].includes(error.code ?? "")
        ) throw new DirectoryError("user_exists", 409);
        throw new DirectoryError("unavailable", 503);
      }
      if (!data.user?.id) throw new DirectoryError("unavailable", 503);
      return data.user.id;
    },
    async setRole(actorId, userId, role, expectedRole, reason) {
      const result = await rpc("admin_set_user_role", {
        p_actor_id: actorId,
        p_user_id: userId,
        p_role: role,
        p_expected_role: expectedRole,
        p_reason: reason,
      });
      if (result?.userId !== userId || result?.role !== role) {
        throw new DirectoryError("unavailable", 503);
      }
      return { userId, role };
    },
  };
}
