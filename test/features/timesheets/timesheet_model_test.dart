import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/timesheets/data/models/timesheet_model.dart';

void main() {
  test('an open timesheet has no checkout + null duration', () {
    final m = TimesheetModel.fromJson({
      'id': 'ts1',
      'job_id': 'j1',
      'builder_id': 'b1',
      'trade_id': 't1',
      'check_in_at': '2026-06-10T08:00:00Z',
      'check_in_lat': -33.8,
      'check_in_lng': 151.2,
      'created_at': '2026-06-10T08:00:00Z',
    });
    expect(m.isOpen, isTrue);
    expect(m.durationMinutes, isNull);
    expect(m.checkInLat, -33.8);
  });

  test('a closed timesheet computes duration in minutes', () {
    final m = TimesheetModel.fromJson({
      'id': 'ts1',
      'job_id': 'j1',
      'builder_id': 'b1',
      'trade_id': 't1',
      'check_in_at': '2026-06-10T08:00:00Z',
      'check_out_at': '2026-06-10T11:30:00Z',
      'created_at': '2026-06-10T08:00:00Z',
    });
    expect(m.isOpen, isFalse);
    expect(m.durationMinutes, 210);
  });
}
