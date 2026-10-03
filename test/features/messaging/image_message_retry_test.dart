import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/data/datasources/message_remote_datasource.dart';
import 'package:jobdun/features/messaging/data/repositories/message_repository_impl.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';

// Fake only the HTTP boundary: exercise the installed Supabase client's real
// multipart upload, error parsing, PostgREST requests and our datasource.
class _Server {
  List<int>? object;
  Map<String, dynamic>? row;
  int messageFailures = 0;
  bool loseCommittedResponse = false;
  bool downloadFails = false;
  bool lookupFails = false;
  bool omitLookupRow = false;
  Completer<void>? lookupGate;
  final lookupStarted = Completer<void>();
  int uploadStatus = 409;
  String duplicateError = 'ResourceAlreadyExists';
  bool legacy = false;
  final requests = <http.Request>[];

  http.Response json(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
    request: requests.last,
  );

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.startsWith('/storage/v1/object/')) {
      if (request.method == 'GET') {
        if (downloadFails) return json({'message': 'denied'}, 403);
        return http.Response.bytes(object!, 200, request: request);
      }
      if (object != null) {
        if (request.headers['x-upsert'] == 'true') {
          return json({
            'message': 'UPDATE denied',
            'error': 'Unauthorized',
          }, 403);
        }
        return json({
          'message': 'The resource already exists',
          'error': duplicateError,
          if (legacy) 'statusCode': '$uploadStatus',
          if (!legacy) 'code': duplicateError,
        }, uploadStatus);
      }
      object = [1, 2, 3];
      return json({'Key': 'chat-attachments/c1/tag.jpg'}, 200);
    }
    if (path == '/rest/v1/messages') {
      if (request.method == 'GET') {
        if (!lookupStarted.isCompleted) lookupStarted.complete();
        await lookupGate?.future;
        if (lookupFails) return json({'message': 'offline', 'code': 'XX'}, 503);
        expect(request.url.queryParameters['conversation_id'], 'eq.c1');
        expect(request.url.queryParameters['client_tag'], startsWith('eq.'));
        return json(row == null || omitLookupRow ? [] : [row], 200);
      }
      if (messageFailures-- > 0) {
        return json({'message': 'temporarily unavailable', 'code': 'XX'}, 503);
      }
      if (row != null) {
        if (request.headers['prefer']?.contains(
              'resolution=ignore-duplicates',
            ) !=
            true) {
          return json({'message': 'duplicate key', 'code': '23505'}, 409);
        }
        expect(
          request.url.queryParameters['on_conflict'],
          'conversation_id,client_tag',
        );
        return http.Response('', 201, request: request);
      }
      row = {
        ...jsonDecode(request.body) as Map<String, dynamic>,
        'id': 'server-message',
        'created_at': '2026-10-01T00:00:00Z',
      };
      if (loseCommittedResponse) {
        loseCommittedResponse = false;
        throw const SocketException('response lost after commit');
      }
      return http.Response('', 201, request: request);
    }
    throw StateError('Unexpected request: ${request.method} $path');
  }
}

void main() {
  late Directory dir;
  late File file;
  late _Server server;
  late SupabaseClient client;
  late MessageRemoteDataSourceImpl datasource;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jobdun-image-retry-');
    file = await File('${dir.path}/photo.jpg').writeAsBytes([1, 2, 3]);
    server = _Server();
    client = SupabaseClient(
      'https://test.invalid',
      'test-anon',
      httpClient: MockClient(server.handle),
    );
    datasource = MessageRemoteDataSourceImpl(client);
  });
  tearDown(() async {
    await client.dispose();
    await dir.delete(recursive: true);
  });

  Future<void> send() => datasource.sendImageMessage(
    conversationId: 'c1',
    senderId: 'me',
    clientTag: 'tag',
    file: file,
    mime: 'image/jpeg',
    width: 20,
    height: 30,
  );

  test(
    'upload success then message failure can retry without UPDATE permission',
    () async {
      server.messageFailures = 1;
      await expectLater(send(), throwsA(isA<ServerException>()));
      await send();
      expect(server.row?['attachment_path'], 'c1/tag.jpg');
      expect(server.row?['attachment_w'], 20);
      expect(server.requests.where((r) => r.method == 'GET'), hasLength(1));
    },
  );

  test(
    'lost committed response retries without a second message row',
    () async {
      server.loseCommittedResponse = true;
      await expectLater(send(), throwsA(isA<ServerException>()));
      await send();
      expect(server.row?['id'], 'server-message');
    },
  );

  for (final error in [
    'ResourceAlreadyExists',
    'KeyAlreadyExists',
    'Duplicate',
  ]) {
    for (final legacy in [false, true]) {
      test('reuses byte-identical $error object with legacy=$legacy', () async {
        server
          ..object = [1, 2, 3]
          ..duplicateError = error
          ..legacy = legacy;
        await send();
        expect(server.row, isNotNull);
        expect(
          server.requests.where((r) => r.method == 'GET').single.url.path,
          '/storage/v1/object/chat-attachments/c1/tag.jpg',
        );
      });
    }
  }

  test('never reuses existing attachment with different bytes', () async {
    server.object = [9, 9, 9];
    await expectLater(send(), throwsA(isA<ServerException>()));
    expect(server.row, isNull);
  });
  for (final status in [403, 500]) {
    test('does not treat status $status as a duplicate', () async {
      server
        ..object = [1, 2, 3]
        ..uploadStatus = status;
      await expectLater(send(), throwsA(isA<ServerException>()));
      expect(server.requests.where((r) => r.method == 'GET'), isEmpty);
      expect(server.row, isNull);
    });
  }
  test('unknown conflict is not accepted as duplicate', () async {
    server
      ..object = [1, 2, 3]
      ..duplicateError = 'SomeOtherConflict';
    await expectLater(send(), throwsA(isA<ServerException>()));
    expect(server.requests.where((r) => r.method == 'GET'), isEmpty);
    expect(server.row, isNull);
  });
  test('failed verification download prevents message insert', () async {
    server
      ..object = [1, 2, 3]
      ..downloadFails = true;
    await expectLater(send(), throwsA(isA<ServerException>()));
    expect(server.row, isNull);
  });

  test(
    'image retry confirms committed message even without realtime echo',
    () async {
      server.loseCommittedResponse = true;
      final container = ProviderContainer(
        overrides: [
          messageRepositoryProvider.overrideWithValue(
            MessageRepositoryImpl(datasource),
          ),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          currentUserIdSyncProvider.overrideWithValue('me'),
        ],
      );
      addTearDown(container.dispose);
      container.listen(currentUserIdProvider, (_, _) {});
      await container.read(currentUserIdProvider.future);
      final controller = container.read(messagingControllerProvider.notifier);
      await controller.sendImage(
        conversationId: 'c1',
        file: file,
        mime: 'image/jpeg',
      );
      final pending = container
          .read(messagingControllerProvider)
          .outboxFor('c1')
          .single;
      expect(pending.failed, isTrue);
      await controller.retryMessage(
        conversationId: 'c1',
        clientTag: pending.clientTag,
      );
      final state = container.read(messagingControllerProvider);
      expect(state.outboxFor('c1'), isEmpty);
      expect(state.messagesFor('c1').single.id, 'server-message');
    },
  );

  for (final fault in [
    'lookup failure',
    'wrong sender',
    'wrong path',
    'wrong mime',
    'missing row',
  ]) {
    test('retry remains recoverable after $fault', () async {
      server.loseCommittedResponse = true;
      final container = ProviderContainer(
        overrides: [
          messageRepositoryProvider.overrideWithValue(
            MessageRepositoryImpl(datasource),
          ),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          currentUserIdSyncProvider.overrideWithValue('me'),
        ],
      );
      addTearDown(container.dispose);
      container.listen(currentUserIdProvider, (_, _) {});
      await container.read(currentUserIdProvider.future);
      final controller = container.read(messagingControllerProvider.notifier);
      await controller.sendImage(
        conversationId: 'c1',
        file: file,
        mime: 'image/jpeg',
      );
      final pending = container
          .read(messagingControllerProvider)
          .outboxFor('c1')
          .single;
      switch (fault) {
        case 'lookup failure':
          server.lookupFails = true;
        case 'wrong sender':
          server.row!['sender_id'] = 'someone-else';
        case 'wrong path':
          server.row!['attachment_path'] = 'c1/different.jpg';
        case 'wrong mime':
          server.row!['attachment_mime'] = 'image/png';
        case 'missing row':
          server.omitLookupRow = true;
      }
      await controller.retryMessage(
        conversationId: 'c1',
        clientTag: pending.clientTag,
      );
      final state = container.read(messagingControllerProvider);
      expect(state.outboxFor('c1').single.failed, isTrue);
      expect(state.messagesFor('c1'), isEmpty);
    });
  }

  for (final dispose in [false, true]) {
    test(
      'late image confirmation is ignored after ${dispose ? 'disposal' : 'account switch'}',
      () async {
        server.loseCommittedResponse = true;
        final accounts = StreamController<String?>();
        addTearDown(accounts.close);
        final container = ProviderContainer(
          overrides: [
            messageRepositoryProvider.overrideWithValue(
              MessageRepositoryImpl(datasource),
            ),
            currentUserIdProvider.overrideWith((ref) => accounts.stream),
            currentUserIdSyncProvider.overrideWithValue('me'),
          ],
        );
        var disposed = false;
        addTearDown(() {
          if (!disposed) container.dispose();
        });
        container.listen(currentUserIdProvider, (_, _) {});
        accounts.add('me');
        await container.read(currentUserIdProvider.future);
        final controller = container.read(messagingControllerProvider.notifier);
        await controller.sendImage(
          conversationId: 'c1',
          file: file,
          mime: 'image/jpeg',
        );
        final pending = container
            .read(messagingControllerProvider)
            .outboxFor('c1')
            .single;
        server.lookupGate = Completer<void>();
        final retry = controller.retryMessage(
          conversationId: 'c1',
          clientTag: pending.clientTag,
        );
        await server.lookupStarted.future.timeout(const Duration(seconds: 2));
        if (dispose) {
          container.dispose();
          disposed = true;
        } else {
          accounts.add('other');
          await Future<void>.delayed(Duration.zero);
        }
        server.lookupGate!.complete();
        await retry;
        if (!dispose) {
          expect(
            container.read(messagingControllerProvider).messagesByConvId,
            isEmpty,
          );
          expect(
            container.read(messagingControllerProvider).outboxByConvId,
            isEmpty,
          );
        }
      },
    );
  }
}
