/// Who an admin broadcast targets. The first three are segment broadcasts; the
/// `singleUser` case carries a profile id typed into the compose form.
///
/// [value] is the exact string the `admin_broadcast` RPC resolves (see
/// 20260609000008): `'all'` → every profile, `'builders'`/`'trades'` → that
/// role, anything else → a single profile id. For [singleUser] the page passes
/// the typed id as the audience instead of this token.
enum BroadcastAudience {
  all('all', 'ALL USERS'),
  builders('builders', 'ALL BUILDERS'),
  trades('trades', 'ALL TRADES'),
  singleUser('single', 'SINGLE USER');

  const BroadcastAudience(this.value, this.label);

  /// The audience token sent to the RPC for the segment cases. Ignored for
  /// [singleUser], where the typed profile id is sent instead.
  final String value;

  /// Human-readable label for the selector + preview.
  final String label;
}
