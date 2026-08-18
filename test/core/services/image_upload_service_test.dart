import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:jobdun/core/services/image_upload_service.dart';

// S6 regression (2026-08-18 audit): camera PlatformExceptions used to escape
// the UploadGuardException-only catch at every call site and die in a
// discarded Future — no camera, no error. The service now converts each code
// image_picker actually throws into user-ready copy.
void main() {
  PlatformException exc(String code) => PlatformException(code: code);

  group('ImageUploadService.pickErrorCopy', () {
    test('camera permission denial names Settings and offers the gallery', () {
      final copy = ImageUploadService.pickErrorCopy(
        exc('camera_access_denied'),
        ImageSource.camera,
      );
      expect(copy, contains('Camera access is off'));
      expect(copy, contains('Settings'));
      expect(copy, contains('gallery'));
    });

    test('photo permission denial names Settings', () {
      for (final code in ['photo_access_denied', 'photo_access_restricted']) {
        final copy = ImageUploadService.pickErrorCopy(
          exc(code),
          ImageSource.gallery,
        );
        expect(copy, contains('Photo access is off'));
        expect(copy, contains('Settings'));
      }
    });

    test('missing camera points at the gallery', () {
      final copy = ImageUploadService.pickErrorCopy(
        exc('no_available_camera'),
        ImageSource.camera,
      );
      expect(copy, contains('No camera available'));
      expect(copy, contains('gallery'));
    });

    test('double-tap (already_active) asks to close the open picker', () {
      final copy = ImageUploadService.pickErrorCopy(
        exc('already_active'),
        ImageSource.camera,
      );
      expect(copy, contains('already open'));
    });

    test('unknown codes fall back to source-specific copy, never raw', () {
      final cameraCopy = ImageUploadService.pickErrorCopy(
        exc('some_future_code'),
        ImageSource.camera,
      );
      final galleryCopy = ImageUploadService.pickErrorCopy(
        exc('some_future_code'),
        ImageSource.gallery,
      );
      expect(cameraCopy, contains('camera'));
      expect(galleryCopy, contains('photos'));
      for (final copy in [cameraCopy, galleryCopy]) {
        expect(copy, isNot(contains('PlatformException')));
        expect(copy, isNot(contains('some_future_code')));
      }
    });
  });
}
