import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Thin wrapper around `Sentry.captureException` / `Sentry.addBreadcrumb`.
///
/// Why this exists: most failures in the codebase live inside catch blocks
/// that return `false` / a `Failure` to the UI without re-throwing. Sentry's
/// auto-capture (FlutterError.onError + zoned errors) only sees *unhandled*
/// throws, so those handled-but-broken paths stay invisible unless we report
/// them explicitly.
///
/// Two entry points:
///
///   • [reportError] — captures an exception with optional tags. Use inside
///     catch blocks for paths that swallow the error after surfacing a
///     user-facing snackbar / "Couldn't do X" state.
///   • [breadcrumb] — adds an auditable trail entry. Use at flow milestones
///     ("user tapped Sign In", "upload selected") so the breadcrumb log on
///     a captured event tells the story.
///
/// Inert when SENTRY_DSN is empty — `Sentry.captureException` becomes a
/// no-op cleanly when no hub is configured.
class SentryReporter {
  const SentryReporter._();

  /// Capture [error] with optional [stackTrace] and structured context.
  ///
  /// [tags] become indexed keys in the Sentry UI (use for low-cardinality
  /// dimensions like `feature: auth`, `action: signIn`). [contexts] are
  /// arbitrary JSON-safe blocks attached to the event under a named key
  /// (use for one-off payloads — emails, IDs, error messages — that are
  /// useful for debugging a single event but you wouldn't search by).
  static Future<void> reportError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, String>? tags,
    Map<String, Object>? contexts,
    String? hint,
  }) async {
    if (kDebugMode) {
      // Loud in debug so engineers see what would have been sent.
      debugPrint('[SentryReporter] $error');
    }
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (tags != null) {
          for (final entry in tags.entries) {
            scope.setTag(entry.key, entry.value);
          }
        }
        if (contexts != null) {
          for (final entry in contexts.entries) {
            scope.setContexts(entry.key, entry.value);
          }
        }
      },
      hint: hint == null ? null : Hint.withMap({'hint': hint}),
    );
  }

  /// Add a breadcrumb. Breadcrumbs are buffered and attached to the next
  /// captured event. [category] groups breadcrumbs in the Sentry timeline —
  /// `auth`, `upload`, `places`, `nav`, `db`, etc. [level] defaults to info.
  static void breadcrumb({
    required String message,
    String category = 'app',
    SentryLevel level = SentryLevel.info,
    Map<String, Object?>? data,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        level: level,
        data: data,
        timestamp: DateTime.now().toUtc(),
      ),
    );
  }
}
