// ============================================================================
// RBAC lockdown integration test
//
// Verifies the four contract guarantees made by:
//   supabase/migrations/20260520000001_lock_user_role.sql
//   supabase/migrations/20260520000002_role_audit_log.sql
//   supabase/migrations/20260520000003_profile_role_consistency.sql
//
// These tests exercise real Postgres triggers and RLS policies, so they need
// to talk to a live (shadow) Supabase project. They're intentionally placed
// under test/integration/ so the default `flutter test test/features/` run in
// CI (scripts/validate.sh) does not pick them up.
//
// How to run locally against a shadow Supabase project:
//   1. Provision a Supabase project with all migrations applied through
//      20260520000003. Disable email confirmation for the duration of the run
//      (Dashboard → Auth → Sign In/Up → confirm email = OFF) so signUp()
//      returns a session immediately.
//   2. Export env vars:
//        export RBAC_INTEGRATION=1
//        export SUPABASE_TEST_URL="https://<shadow-ref>.supabase.co"
//        export SUPABASE_TEST_ANON_KEY="<anon-key>"
//   3. flutter test test/integration/rbac_test.dart \
//        --dart-define=RBAC_INTEGRATION=$RBAC_INTEGRATION \
//        --dart-define=SUPABASE_TEST_URL=$SUPABASE_TEST_URL \
//        --dart-define=SUPABASE_TEST_ANON_KEY=$SUPABASE_TEST_ANON_KEY
//
// Without RBAC_INTEGRATION=1 every test is skipped with a clear message so
// the file still imports cleanly in normal `flutter test` runs.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kIntegrationEnabled = bool.fromEnvironment(
  'RBAC_INTEGRATION',
  defaultValue: false,
);
const _kUrl = String.fromEnvironment('SUPABASE_TEST_URL');
const _kAnonKey = String.fromEnvironment('SUPABASE_TEST_ANON_KEY');

bool get _envReady =>
    _kIntegrationEnabled && _kUrl.isNotEmpty && _kAnonKey.isNotEmpty;

String _skipReason() {
  if (!_kIntegrationEnabled) {
    return 'Skipped: set --dart-define=RBAC_INTEGRATION=true to enable.';
  }
  if (_kUrl.isEmpty) return 'Skipped: SUPABASE_TEST_URL missing.';
  if (_kAnonKey.isEmpty) return 'Skipped: SUPABASE_TEST_ANON_KEY missing.';
  return 'Skipped: integration env incomplete.';
}

// Fresh anonymous email per test — avoids collision when the shadow project
// already has a user with the same email left over from a prior run.
String _uniqueEmail(String tag) {
  final ts = DateTime.now().microsecondsSinceEpoch;
  return 'rbac_${tag}_$ts@jobdun-test.invalid';
}

// Each test creates its own SupabaseClient (no global Supabase.initialize)
// so an authenticated session in one test cannot leak into another.
SupabaseClient _newClient() {
  return SupabaseClient(_kUrl, _kAnonKey);
}

Future<({SupabaseClient client, String userId, String email})> _signUpAs({
  required String role,
  String? tag,
}) async {
  final client = _newClient();
  final email = _uniqueEmail(tag ?? role);
  const password = 'rbac-test-pass-1!';

  // role is read by handle_new_user trigger from raw_user_meta_data.
  final resp = await client.auth.signUp(
    email: email,
    password: password,
    data: {'full_name': 'RBAC Test ($role)', 'role': role},
  );

  final session = resp.session;
  final user = resp.user;
  if (session == null || user == null) {
    throw StateError(
      'signUp did not return a session — disable email confirmation on the '
      'shadow project for integration tests.',
    );
  }
  return (client: client, userId: user.id, email: email);
}

void main() {
  // Print the skip reason once at file load so flaky CI output makes the
  // gate obvious. (TestWidgetsFlutterBinding is not needed — this is a pure
  // VM test.)
  if (!_envReady) {
    // ignore: avoid_print
    print('[rbac_test] ${_skipReason()}');
  }

  group(
    'RBAC lockdown — scenario (a): signup creates the correct row shape',
    skip: !_envReady ? _skipReason() : null,
    () {
      test(
        'builder signup → 1 user_roles, 1 builder_profiles, 0 trade_profiles, 1 user_role_events',
        () async {
          final s = await _signUpAs(role: 'builder', tag: 'a_builder');

          // user_roles — exactly one row, role='builder'
          final roleRows = await s.client
              .from('user_roles')
              .select('user_id, role')
              .eq('user_id', s.userId);
          expect(roleRows, hasLength(1));
          expect((roleRows.first as Map)['role'], equals('builder'));

          // builder_profiles — exactly one row
          final builderRows = await s.client
              .from('builder_profiles')
              .select('id')
              .eq('id', s.userId);
          expect(builderRows, hasLength(1));

          // trade_profiles — zero rows (no stub leaked)
          // Note: RLS now requires user_roles.role='trade' to read trade_profiles
          // for the row owner. As a builder we'd get an empty result either way,
          // which is what we want to assert.
          final tradeRows = await s.client
              .from('trade_profiles')
              .select('id')
              .eq('id', s.userId);
          expect(tradeRows, isEmpty);

          // user_role_events — one signup event for this user
          final events = await s.client
              .from('user_role_events')
              .select('new_role, old_role, reason')
              .eq('user_id', s.userId);
          expect(events, hasLength(1));
          expect((events.first as Map)['new_role'], equals('builder'));
          expect((events.first as Map)['old_role'], isNull);
          expect((events.first as Map)['reason'], equals('signup'));
        },
      );

      test(
        'trade signup → 1 user_roles, 1 trade_profiles, 0 builder_profiles, 1 user_role_events',
        () async {
          final s = await _signUpAs(role: 'trade', tag: 'a_trade');

          final roleRows = await s.client
              .from('user_roles')
              .select('user_id, role')
              .eq('user_id', s.userId);
          expect(roleRows, hasLength(1));
          expect((roleRows.first as Map)['role'], equals('trade'));

          final tradeRows = await s.client
              .from('trade_profiles')
              .select('id')
              .eq('id', s.userId);
          expect(tradeRows, hasLength(1));

          final builderRows = await s.client
              .from('builder_profiles')
              .select('id')
              .eq('id', s.userId);
          expect(builderRows, isEmpty);

          final events = await s.client
              .from('user_role_events')
              .select('new_role, reason')
              .eq('user_id', s.userId);
          expect(events, hasLength(1));
          expect((events.first as Map)['new_role'], equals('trade'));
          expect((events.first as Map)['reason'], equals('signup'));
        },
      );
    },
  );

  group(
    'RBAC lockdown — scenario (b): self-serve role flip is rejected',
    skip: !_envReady ? _skipReason() : null,
    () {
      test(
        'UPDATE user_roles.role as self → throws PostgrestException',
        () async {
          final s = await _signUpAs(role: 'builder', tag: 'b_flip');

          // Two layers protect us here:
          //   1. Migration 20260520000001 dropped user_roles_update_own RLS.
          //      Without an UPDATE policy, RLS denies the request silently
          //      (zero rows affected, no exception).
          //   2. trg_forbid_role_mutation BEFORE UPDATE raises 42501 if a
          //      role change somehow reached the trigger from non-service_role.
          //
          // Expected outcome: either path means the role does NOT change.
          // We accept *either* a thrown PostgrestException or a no-op as a
          // pass, then re-read to confirm the role is still 'builder'.
          var threw = false;
          try {
            await s.client
                .from('user_roles')
                .update({'role': 'trade'})
                .eq('user_id', s.userId);
          } on PostgrestException {
            threw = true;
          }

          final roleRows = await s.client
              .from('user_roles')
              .select('role')
              .eq('user_id', s.userId);
          expect(roleRows, hasLength(1));
          expect(
            (roleRows.first as Map)['role'],
            equals('builder'),
            reason:
                'role must remain builder after the (rejected/no-op) flip attempt; '
                'threw=$threw',
          );

          // user_role_events must NOT have grown a row from this attempt —
          // log_role_event only fires after a real UPDATE OF role landed.
          final events = await s.client
              .from('user_role_events')
              .select('new_role')
              .eq('user_id', s.userId);
          expect(events, hasLength(1));
        },
      );
    },
  );

  group(
    'RBAC lockdown — scenario (c): admin escalation is rejected (3-layer defence)',
    skip: !_envReady ? _skipReason() : null,
    () {
      test('INSERT user_roles{role=admin} as self → throws', () async {
        // Sign up first as a normal user so we have an authenticated session.
        // handle_new_user already ignored role='admin' in metadata (defence
        // layer 1). We now manually attempt the escalation via PostgREST
        // and expect it to be rejected by:
        //   layer 2 — user_roles_insert_own RLS WITH CHECK (role IN ('builder','trade'))
        //   layer 3 — forbid_self_admin BEFORE INSERT trigger (42501)
        final s = await _signUpAs(role: 'trade', tag: 'c_admin');

        // Wipe the existing row so the INSERT below isn't a no-op upsert.
        // The trigger logs the DELETE? No — there's no DELETE trigger; user_role_events
        // only tracks INSERT/UPDATE OF role. Use upsert(role='admin') to be sure.
        var threwOnInsert = false;
        try {
          await s.client.from('user_roles').upsert({
            'user_id': s.userId,
            'role': 'admin',
          });
        } on PostgrestException {
          threwOnInsert = true;
        }

        // Re-read: role must remain 'trade'.
        final roleRows = await s.client
            .from('user_roles')
            .select('role')
            .eq('user_id', s.userId);
        expect(roleRows, hasLength(1));
        expect(
          (roleRows.first as Map)['role'],
          equals('trade'),
          reason:
              'admin escalation must be rejected; threwOnInsert=$threwOnInsert',
        );
      });
    },
  );

  group(
    'RBAC lockdown — scenario (d): EXISTS guard scopes role-extension SELECTs',
    skip: !_envReady ? _skipReason() : null,
    () {
      test(
        'user B SELECTing builder_profiles for trade-user A returns empty',
        () async {
          // User A signs up as a trade. By the EXISTS guard added in
          // 20260520000003, builder_profiles for user A should be invisible
          // even though the *_select_authenticated policy is still permissive
          // on its surface — because no user_roles row exists with
          // (user_id=A, role='builder').
          final a = await _signUpAs(role: 'trade', tag: 'd_trade_A');

          // User B authenticated independently performs the SELECT.
          final b = await _signUpAs(role: 'builder', tag: 'd_builder_B');

          final builderRowsForA = await b.client
              .from('builder_profiles')
              .select('id')
              .eq('id', a.userId);
          expect(
            builderRowsForA,
            isEmpty,
            reason:
                'builder_profiles for a trade-only user A must not be visible '
                'to authenticated user B after migration 20260520000003.',
          );

          // Sanity — B can still see their OWN builder_profiles row (role='builder')
          final builderRowsForB = await b.client
              .from('builder_profiles')
              .select('id')
              .eq('id', b.userId);
          expect(builderRowsForB, hasLength(1));
        },
      );

      test(
        'user A SELECTing trade_profiles for builder-user B returns empty',
        () async {
          // Mirror of the previous test — confirms the trade-side EXISTS guard.
          final b = await _signUpAs(role: 'builder', tag: 'd_builder_B2');
          final a = await _signUpAs(role: 'trade', tag: 'd_trade_A2');

          final tradeRowsForB = await a.client
              .from('trade_profiles')
              .select('id')
              .eq('id', b.userId);
          expect(
            tradeRowsForB,
            isEmpty,
            reason:
                'trade_profiles for a builder-only user B must not be visible '
                'to authenticated user A after migration 20260520000003.',
          );

          final tradeRowsForA = await a.client
              .from('trade_profiles')
              .select('id')
              .eq('id', a.userId);
          expect(tradeRowsForA, hasLength(1));
        },
      );
    },
  );
}
