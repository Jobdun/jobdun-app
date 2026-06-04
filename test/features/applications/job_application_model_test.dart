import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/applications/data/models/job_application_model.dart';

Map<String, dynamic> _baseRow() => {
  'id': 'a1',
  'job_id': 'j1',
  'trade_id': 't1',
  'builder_id': 'b1',
  'status': 'pending',
  'created_at': '2026-05-01T00:00:00.000Z',
  'updated_at': '2026-05-01T00:00:00.000Z',
};

void main() {
  group('JobApplicationModel.fromJson — trade avatar', () {
    test('maps embedded profiles.avatar_url to tradeAvatarUrl', () {
      final model = JobApplicationModel.fromJson({
        ..._baseRow(),
        'profiles': {'avatar_url': 'https://cdn.example.com/t1.jpg'},
      });
      expect(model.tradeAvatarUrl, 'https://cdn.example.com/t1.jpg');
    });

    test('tradeAvatarUrl is null when no profiles embed is present', () {
      final model = JobApplicationModel.fromJson(_baseRow());
      expect(model.tradeAvatarUrl, isNull);
    });

    test('tradeAvatarUrl is null when avatar_url is absent in the embed', () {
      final model = JobApplicationModel.fromJson({
        ..._baseRow(),
        'profiles': {'id': 't1'},
      });
      expect(model.tradeAvatarUrl, isNull);
    });
  });
}
