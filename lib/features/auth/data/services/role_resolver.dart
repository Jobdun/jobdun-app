import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/user_role.dart';

/// Resolves which [UserRole] the active user has, plus the onboarding flag.
///
/// Role lives in `user_roles` and is injected into the JWT via the
/// `custom_access_token_hook`. We read it from the claim first (cheap, no
/// round-trip), then fall back to a DB lookup when the claim is absent
/// (custom hook not wired, post-refresh race, SSO sign-up).
///
/// Also owns [setRoleAndStubProfile] — the RoleSelectionSheet entry point —
/// which honours an existing immutable role row instead of overwriting it.
class RoleResolver {
  RoleResolver(this._client);
  final supabase.SupabaseClient _client;

  UserRole? roleFromSession() {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    try {
      final parts = session.accessToken.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final claims = jsonDecode(decoded) as Map<String, dynamic>;
      final roleStr = claims['user_role'] as String?;
      if (roleStr == null) return null;
      return UserRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => UserRole.trade,
      );
    } catch (_) {
      return null;
    }
  }

  // Fallback when the JWT carries no user_role claim — e.g. the
  // custom_access_token_hook isn't active in the dashboard, or a post-
  // refreshSession race. user_roles is the source of truth; without this the
  // role sheet re-appears on /home even though the user already picked a role.
  Future<UserRole?> roleFromDb(String userId) async {
    try {
      final row = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();
      final roleStr = row?['role'] as String?;
      if (roleStr == null) return null;
      return UserRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => UserRole.trade,
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether `profiles.onboarding_completed_at` is non-null for the user.
  /// Best-effort — swallows exceptions so a transient fetch error doesn't
  /// block the sign-in path.
  Future<bool> isOnboardingComplete(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select('onboarding_completed_at')
          .eq('id', userId)
          .maybeSingle();
      return data?['onboarding_completed_at'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Resolves the user's role using the JWT-first / DB-fallback policy.
  Future<UserRole?> resolveRole(String userId) async {
    return roleFromSession() ?? await roleFromDb(userId);
  }

  /// Sets the role and creates the role-specific stub profile.
  ///
  /// Role is IMMUTABLE per the RBAC lockdown (supabase/migrations/
  /// 20260520000001_lock_user_role.sql): once a user_roles row exists, only
  /// the service_role can mutate it. This method:
  ///   1. Reads user_roles for this user
  ///   2. If a row exists, honours it (does NOT overwrite) — returns the
  ///      persisted role and proceeds to stub-profile creation for that role,
  ///      not the role the user picked in the sheet.
  ///   3. If no row exists, INSERTs (permitted by user_roles_insert_own RLS:
  ///      auth.uid() = user_id AND role IN ('builder','trade')).
  ///   4. Creates the role-specific stub if missing (idempotent on PK 'id').
  ///   5. refreshSession() so the new JWT claim is live.
  Future<UserRole> setRoleAndStubProfile({
    required String userId,
    required UserRole requestedRole,
  }) async {
    // Ensure profiles row exists before inserting role-specific child table.
    // The handle_new_user trigger normally creates this, but may race on SSO.
    await _client.from('profiles').upsert({'id': userId}, onConflict: 'id');

    // Step 1: look up any existing role row.
    final existing = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();

    UserRole effectiveRole = requestedRole;
    if (existing != null) {
      final priorName = existing['role'] as String?;
      effectiveRole = UserRole.values.firstWhere(
        (r) => r.name == priorName,
        orElse: () => requestedRole,
      );
    } else {
      // Step 3: no row → INSERT. Never upsert: UPDATE is blocked by the
      // forbid_role_mutation trigger from 20260520000001.
      await _client.from('user_roles').insert({
        'user_id': userId,
        'role': effectiveRole.name,
      });
    }

    // Step 4: create the matching stub if missing. Upsert by PK is
    // idempotent and not affected by the role-mutation trigger.
    if (effectiveRole == UserRole.builder) {
      await _client.from('builder_profiles').upsert({
        'id': userId,
      }, onConflict: 'id');
    } else if (effectiveRole == UserRole.trade) {
      await _client.from('trade_profiles').upsert({
        'id': userId,
      }, onConflict: 'id');
    }

    // Step 5: force a JWT refresh so the user_role claim is in the session.
    await _client.auth.refreshSession();

    return effectiveRole;
  }
}
