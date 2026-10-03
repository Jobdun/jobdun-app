import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/features/applications/data/datasources/application_remote_datasource.dart';
import 'package:jobdun/features/applications/domain/entities/job_application.dart';

void main() {
  test(
    'status and withdrawal request a returned row to confirm the write',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'http://localhost:54321',
        'test',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'id': 'a'}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final ds = ApplicationRemoteDataSourceImpl(client);
      await ds.updateStatus('a', ApplicationStatus.shortlisted);
      await ds.withdraw('a');
      for (final request in requests) {
        expect(request.headers['Prefer'], contains('return=representation'));
        expect(request.url.queryParameters['select'], 'id');
      }
    },
  );
  test('a hidden or missing row surfaces a failure', () async {
    final client = SupabaseClient(
      'http://localhost:54321',
      'test',
      httpClient: MockClient((request) async {
        if (request.headers['Accept']?.contains('object') == true) {
          return http.Response(
            jsonEncode({'code': 'PGRST116', 'message': 'No row returned'}),
            406,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);
    final ds = ApplicationRemoteDataSourceImpl(client);
    await expectLater(ds.withdraw('missing'), throwsA(isA<ServerException>()));
  });
}
