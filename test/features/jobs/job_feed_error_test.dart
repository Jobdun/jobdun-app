import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/features/jobs/data/datasources/job_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

void main() {
  for (final scenario in [
    (
      'offline',
      http.ClientException('SocketException: private.example/rest/v1/jobs'),
      "You're offline. Check your connection and try again.",
    ),
    (
      'timeout',
      TimeoutException('private.example/rest/v1/jobs'),
      'Loading jobs took too long. Please try again.',
    ),
    (
      'server',
      const PostgrestException(message: 'private database details'),
      "Couldn't load jobs. Please try again.",
    ),
  ]) {
    test('${scenario.$1} failure does not expose transport details', () async {
      final client = SupabaseClient(
        'https://test.example',
        'test-key',
        httpClient: MockClient((_) async => throw scenario.$2),
      );
      addTearDown(client.dispose);
      await expectLater(
        JobRemoteDataSourceImpl(client).getJobs(),
        throwsA(
          isA<ServerException>().having(
            (error) => error.message,
            'safe message',
            scenario.$3,
          ),
        ),
      );
    });
  }
}
