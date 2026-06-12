import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/navigation/notification_routes.dart';

void main() {
  group('resolveNotificationRoute', () {
    test('message type with conversation_id routes to the thread', () {
      expect(
        resolveNotificationRoute(
          type: 'message_received',
          data: {'conversation_id': 'c1'},
        ),
        '/messages/c1',
      );
    });

    test('conversation_id alone routes to the thread', () {
      expect(
        resolveNotificationRoute(data: {'conversation_id': 'c2'}),
        '/messages/c2',
      );
    });

    test('message type without conversation_id falls back to inbox', () {
      expect(
        resolveNotificationRoute(type: 'message_received', data: {}),
        '/messages',
      );
    });

    test('application types route to applications', () {
      expect(
        resolveNotificationRoute(
          type: 'application_received',
          data: {'job_id': 'j1', 'application_id': 'a1'},
        ),
        '/applications',
      );
      expect(
        resolveNotificationRoute(
          type: 'application_status',
          data: {'job_id': 'j1', 'application_id': 'a1', 'status': 'hired'},
        ),
        '/applications',
      );
    });

    test('new_job routes to the job detail', () {
      expect(
        resolveNotificationRoute(type: 'new_job', data: {'job_id': 'j7'}),
        '/jobs/j7',
      );
    });

    test('quote types route to the job detail', () {
      expect(
        resolveNotificationRoute(
          type: 'quote_requested',
          data: {'job_id': 'j8', 'quote_request_id': 'q1'},
        ),
        '/jobs/j8',
      );
    });

    test('application_id without type still routes to applications', () {
      // FCM pushes carry only the data payload (no type field) — the
      // application_id key is the signal.
      expect(
        resolveNotificationRoute(
          data: {'job_id': 'j1', 'application_id': 'a1'},
        ),
        '/applications',
      );
    });

    test('job_id alone routes to the job detail', () {
      expect(resolveNotificationRoute(data: {'job_id': 'j9'}), '/jobs/j9');
    });

    test('job type without job_id falls back to notifications', () {
      expect(
        resolveNotificationRoute(type: 'new_job', data: {}),
        '/notifications',
      );
    });

    test('unknown or empty payloads fall back to notifications', () {
      expect(resolveNotificationRoute(data: {}), '/notifications');
      expect(
        resolveNotificationRoute(type: 'announcement', data: {}),
        '/notifications',
      );
    });

    test('non-string payload values are coerced', () {
      expect(resolveNotificationRoute(data: {'job_id': 42}), '/jobs/42');
    });
  });
}
