@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jobdun/core/services/image_upload_service.dart';

void main() {
  test('pickCropCompress refuses on web with actionable copy', () async {
    await expectLater(
      () => ImageUploadService.pickCropCompress(
        source: ImageSource.gallery,
        aspect: ImageAspect.square,
      ),
      throwsA(
        isA<UploadGuardException>().having(
          (e) => e.message,
          'message',
          contains('browser'),
        ),
      ),
    );
  });
}
