import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';
import 'package:jobdun/features/jobs/data/datasources/job_remote_datasource.dart';

void main() {
  test(
    'guest apprenticeship filters and range are sent in the same request',
    () async {
      late Uri uri;
      final client = SupabaseClient(
        'http://localhost:54321',
        'test',
        httpClient: MockClient((request) async {
          uri = request.url;
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await JobRemoteDataSourceImpl(client).getJobs(
        filter: const JobFilter(
          jobKind: JobKind.apprenticeship,
          openToApprentices: true,
          tradeType: 'Carpenter',
          searchQuery: 'Sydney',
        ),
        limit: 20,
        offset: 20,
      );
      expect(uri.path, endsWith('jobs_public_browse'));
      expect(uri.queryParameters['job_kind'], 'eq.apprenticeship');
      expect(uri.queryParameters['open_to_apprentices'], 'eq.true');
      expect(uri.queryParameters['trade_type_required'], 'eq.Carpenter');
      expect(uri.queryParameters['offset'], '20');
      expect(uri.queryParameters['limit'], '20');
      expect(uri.queryParameters['select'], contains('job_kind'));
      expect(
        uri.queryParameters['select'],
        contains('requires_public_liability'),
      );
    },
  );
}
