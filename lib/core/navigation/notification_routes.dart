/// Maps a notification's `type` + `data` payload to an in-app route. Shared by
/// the notifications page (row tap), push taps (background/cold start), and
/// foreground banner taps so every entry point lands on the same screen.
///
/// Payload shapes come from the DB producers (see
/// supabase/migrations/20260609000009/000010, 20260610000005): messages carry
/// `conversation_id`, applications `job_id`+`application_id`, jobs/quotes
/// `job_id`. FCM data values arrive as strings; DB jsonb may not — coerce.
String resolveNotificationRoute({String? type, Map<String, dynamic>? data}) {
  final t = type ?? '';
  final d = data ?? const {};

  final conversationId = _id(d['conversation_id']);
  if (conversationId != null) return '/messages/$conversationId';
  if (t.startsWith('message')) return '/messages';

  // FCM pushes deliver only the data payload (no type), so the
  // application_id key doubles as the type signal.
  if (t.startsWith('application') || _id(d['application_id']) != null) {
    return '/applications';
  }

  final jobId = _id(d['job_id']);
  if (jobId != null) return '/jobs/$jobId';

  return '/notifications';
}

String? _id(Object? value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
