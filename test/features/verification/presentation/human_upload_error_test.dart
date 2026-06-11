import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/verification/presentation/widgets/manual_upload_form.dart';

// U1.2: users never see raw exception strings — every failure maps to a
// human-readable line. The raw error still reaches the funnel log.
void main() {
  group('humanUploadError', () {
    test('network failures map to the connection line', () {
      expect(
        humanUploadError(Exception('SocketException: Failed host lookup')),
        "Couldn't upload — check your connection and try again.",
      );
      expect(
        humanUploadError(Exception('TimeoutException after 30s')),
        "Couldn't upload — check your connection and try again.",
      );
    });

    test('size failures map to the too-big line', () {
      expect(
        humanUploadError(Exception('413 Payload Too Large')),
        'That file is too big — keep it under 10 MB.',
      );
      expect(
        humanUploadError(
          Exception('The object exceeded the maximum allowed size'),
        ),
        'That file is too big — keep it under 10 MB.',
      );
    });

    test('auth failures map to the refused line', () {
      expect(
        humanUploadError(Exception('StorageException 403 Unauthorized')),
        'Upload was refused. Log out and back in, then retry.',
      );
    });

    test('everything else maps to the generic line', () {
      expect(
        humanUploadError(Exception('PostgrestException: something odd')),
        'Something went wrong. Try again in a minute.',
      );
    });

    test('no mapping ever leaks the word Exception', () {
      for (final e in [
        Exception('SocketException: x'),
        Exception('413'),
        Exception('403'),
        Exception('weird'),
      ]) {
        expect(humanUploadError(e).contains('Exception'), isFalse);
      }
    });
  });
}
