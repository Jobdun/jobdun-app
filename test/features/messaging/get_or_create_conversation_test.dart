import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/messaging/data/datasources/message_remote_datasource.dart';
import 'package:jobdun/features/messaging/data/repositories/message_repository_impl.dart';
import 'package:jobdun/features/messaging/domain/usecases/get_or_create_conversation.dart';

class _MockDs extends Mock implements MessageRemoteDataSource {}

void main() {
  late _MockDs ds;
  late MessageRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = MessageRepositoryImpl(ds);
  });

  test('repo returns the conversation id from the datasource', () async {
    when(
      () => ds.getOrCreateConversation(
        builderId: any(named: 'builderId'),
        tradeId: any(named: 'tradeId'),
        jobId: any(named: 'jobId'),
      ),
    ).thenAnswer((_) async => 'conv-1');

    final r = await repo.getOrCreateConversation(
      builderId: 'b',
      tradeId: 't',
      jobId: 'j',
    );

    expect(r, const Right<Failure, String>('conv-1'));
  });

  test('repo maps ServerException to ServerFailure', () async {
    when(
      () => ds.getOrCreateConversation(
        builderId: any(named: 'builderId'),
        tradeId: any(named: 'tradeId'),
        jobId: any(named: 'jobId'),
      ),
    ).thenThrow(const ServerException('boom'));

    final r = await repo.getOrCreateConversation(builderId: 'b', tradeId: 't');

    expect(r.isLeft(), isTrue);
    r.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected left'),
    );
  });

  test('use case delegates to the repo', () async {
    when(
      () => ds.getOrCreateConversation(
        builderId: any(named: 'builderId'),
        tradeId: any(named: 'tradeId'),
        jobId: any(named: 'jobId'),
      ),
    ).thenAnswer((_) async => 'conv-9');

    final result = await GetOrCreateConversation(
      repo,
    ).call(builderId: 'b', tradeId: 't');

    expect(result, const Right<Failure, String>('conv-9'));
  });
}
