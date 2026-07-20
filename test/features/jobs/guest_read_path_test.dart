import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;

import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/features/jobs/data/datasources/job_feed_cache_datasource.dart';
import 'package:jobdun/features/jobs/data/datasources/job_remote_datasource.dart';
import 'package:jobdun/features/jobs/data/models/job_model.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';

void main() {
  // A real client with no session — guest state. None of these tests may
  // touch the network; the guards under test must fire before any request.
  final guestClient = SupabaseClient('http://localhost:54321', 'anon-key');

  group('guest feed cache guard', () {
    test('getFirstPage fast-fails without a session (no network)', () async {
      final ds = JobFeedCacheDataSourceImpl(guestClient);
      await expectLater(
        ds.getFirstPage(limit: 20),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('guest read table selection', () {
    test('reads jobs_public_browse when there is no session', () {
      final ds = JobRemoteDataSourceImpl(guestClient);
      expect(ds.readTable, 'jobs_public_browse');
    });
  });

  group('JobModel parses a jobs_public_browse row', () {
    // Shape returned by the anon view: rounded coords, suburb-level
    // formatted_address, place_id/hired_trade_id absent-or-null, constant
    // NULL deleted_at.
    final viewRow = <String, dynamic>{
      'id': 'j1',
      'builder_id': 'b1',
      'title': '3-phase switchboard install',
      'description': 'Licensed sparkie needed.',
      'suburb': 'Sydney',
      'state': 'NSW',
      'postcode': '2000',
      'trade_type_required': 'Electrician',
      'budget_amount': 1800,
      'pricing_unit': 'per_job',
      'pricing_type': 'builder_set',
      'urgency': 'standard',
      'requires_verified': true,
      'requires_white_card': false,
      'requires_public_liability': true,
      'required_certifications': <dynamic>[],
      'start_date': '2026-08-01',
      'estimated_duration_days': 3,
      'duration_text': null,
      'application_count': 4,
      'view_count': 41,
      'status': 'open',
      'published_at': '2026-07-18T01:00:00Z',
      'created_at': '2026-07-18T00:00:00Z',
      'updated_at': '2026-07-18T01:00:00Z',
      'latitude': -33.87,
      'longitude': 151.21,
      'formatted_address': 'Sydney, NSW',
      'place_id': null,
      'deleted_at': null,
    };

    test('maps every guest-visible field and nulls the withheld ones', () {
      final m = JobModel.fromJson(viewRow);
      expect(m.id, 'j1');
      expect(m.builderId, 'b1');
      expect(m.placeId, isNull);
      expect(m.hiredTradeId, isNull);
      expect(m.formattedAddress, 'Sydney, NSW');
      expect(m.latitude, -33.87);
      expect(m.status, JobStatus.open);
      expect(m.applicationCount, 4);
    });
  });
}
