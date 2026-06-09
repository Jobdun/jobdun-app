import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/scheduling/data/models/booking_model.dart';
import 'package:jobdun/features/scheduling/domain/entities/booking.dart';

void main() {
  test('fromJson maps fields, date-only, status + joined names', () {
    final m = BookingModel.fromJson({
      'id': 'bk1',
      'job_id': 'j1',
      'builder_id': 'b1',
      'trade_id': 't1',
      'scheduled_date': '2026-06-20',
      'status': 'scheduled',
      'note': 'Bring your own tools',
      'created_at': '2026-06-10T02:00:00Z',
      'jobs': {'title': 'Deck build'},
      'builder_profiles': {'company_name': 'Acme Builders'},
      'trade_profiles': {'full_name': 'Jo Tradie'},
    });

    expect(m.scheduledDate, DateTime(2026, 6, 20));
    expect(m.status, BookingStatus.scheduled);
    expect(m.isActive, isTrue);
    expect(m.jobTitle, 'Deck build');
    expect(m.builderCompanyName, 'Acme Builders');
    expect(m.tradeFullName, 'Jo Tradie');
  });

  test('cancelled booking is not active', () {
    final m = BookingModel.fromJson({
      'id': 'bk1',
      'job_id': 'j1',
      'builder_id': 'b1',
      'trade_id': 't1',
      'scheduled_date': '2026-06-20',
      'status': 'cancelled',
      'created_at': '2026-06-10T02:00:00Z',
    });
    expect(m.status, BookingStatus.cancelled);
    expect(m.isActive, isFalse);
  });
}
