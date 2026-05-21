import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/auth/domain/entities/app_user.dart';
import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/auth/domain/repositories/auth_repository.dart';
import 'package:jobdun/features/auth/domain/usecases/sign_in.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late SignIn signIn;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    signIn = SignIn(mockRepo);
  });

  const tEmail = 'worker@jobdun.com';
  const tPassword = 'password123';
  const tUser = AppUser(id: 'user-abc', email: tEmail, role: UserRole.trade);

  group('SignIn use case', () {
    test('returns AppUser when credentials are correct', () async {
      when(
        () => mockRepo.signIn(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Right(tUser));

      final result = await signIn(email: tEmail, password: tPassword);

      expect(result, const Right<Failure, AppUser>(tUser));
      verify(
        () => mockRepo.signIn(email: tEmail, password: tPassword),
      ).called(1);
      verifyNoMoreInteractions(mockRepo);
    });

    test('returns AuthFailure on wrong credentials', () async {
      const failure = AuthFailure('Invalid login credentials');
      when(
        () => mockRepo.signIn(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signIn(email: tEmail, password: tPassword);

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns NetworkFailure when offline', () async {
      const failure = NetworkFailure();
      when(
        () => mockRepo.signIn(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signIn(email: tEmail, password: tPassword);

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('delegates to repository exactly once per call', () async {
      when(
        () => mockRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Right(tUser));

      await signIn(email: tEmail, password: tPassword);
      await signIn(email: tEmail, password: tPassword);

      verify(
        () => mockRepo.signIn(email: tEmail, password: tPassword),
      ).called(2);
    });

    test('preserves all user fields from repository response', () async {
      const detailedUser = AppUser(
        id: 'builder-xyz',
        email: tEmail,
        role: UserRole.builder,
        fullName: 'Ken Garcia',
      );
      when(
        () => mockRepo.signIn(email: tEmail, password: tPassword),
      ).thenAnswer((_) async => const Right(detailedUser));

      final result = await signIn(email: tEmail, password: tPassword);

      result.fold((_) => fail('Expected user'), (user) {
        expect(user.role, UserRole.builder);
        expect(user.fullName, 'Ken Garcia');
      });
    });
  });
}
