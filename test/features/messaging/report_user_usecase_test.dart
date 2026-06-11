import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/messaging/domain/entities/report_submission.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/domain/usecases/report_user.dart';

class _MockRepo extends Mock implements MessageRepository {}

ReportSubmission _report({
  ReportReason reason = ReportReason.spamOrScam,
  String? details,
}) => ReportSubmission(
  reporterId: 'me',
  reportedId: 'them',
  conversationId: 'c1',
  reason: reason,
  details: details,
);

void main() {
  setUpAll(() => registerFallbackValue(_report()));

  late _MockRepo repo;
  late ReportUser usecase;

  setUp(() {
    repo = _MockRepo();
    usecase = ReportUser(repo);
  });

  test('valid report reaches the repo', () async {
    when(
      () => repo.reportUser(report: any(named: 'report')),
    ).thenAnswer((_) async => right(null));
    final r = await usecase(_report());
    expect(r.isRight(), isTrue);
    verify(() => repo.reportUser(report: any(named: 'report'))).called(1);
  });

  test('reason "other" without details is rejected before the repo', () async {
    final r = await usecase(_report(reason: ReportReason.other, details: '  '));
    r.fold(
      (f) => expect(f, isA<ValidationFailure>()),
      (_) => fail('expected validation failure'),
    );
    verifyNever(() => repo.reportUser(report: any(named: 'report')));
  });

  test('details over 500 chars are rejected before the repo', () async {
    final r = await usecase(_report(details: 'x' * 501));
    r.fold(
      (f) => expect(f, isA<ValidationFailure>()),
      (_) => fail('expected validation failure'),
    );
    verifyNever(() => repo.reportUser(report: any(named: 'report')));
  });
}
