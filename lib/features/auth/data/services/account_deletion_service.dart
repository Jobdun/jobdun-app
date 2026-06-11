import 'package:supabase_flutter/supabase_flutter.dart';

/// Play-policy account deletion (in-app deletion is mandatory for apps with
/// account creation). Calls the `delete_my_account` SECURITY DEFINER RPC,
/// which deletes the caller's `auth.users` row server-side and cascades
/// through the public schema — a user can only ever delete themselves.
///
/// Lives in auth `data/services/` per the documented auth exception (no
/// use-case/repo ceremony for stateful auth flows — see CLAUDE.md).
class AccountDeletionService {
  AccountDeletionService(this._client);

  final SupabaseClient _client;

  /// Throws on failure (e.g. a RESTRICT FK blocking the cascade) — the
  /// caller surfaces that as a "contact support" error. On success the
  /// session is already dead server-side; the caller still signs out
  /// locally to clear state and route to login.
  Future<void> deleteMyAccount() async {
    await _client.rpc('delete_my_account');
  }
}
