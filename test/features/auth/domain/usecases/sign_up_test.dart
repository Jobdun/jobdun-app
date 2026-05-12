import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/auth/domain/entities/app_user.dart';
import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/auth/domain/repositories/auth_repository.dart';
import 'package:jobdun/features/auth/domain/usecases/sign_up.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late SignUp signUp;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    signUp = SignUp(mockRepo);
  });

  const tEmail = 'newuser@jobdun.com';
  const tPassword = 'securePass99';
  const tName = 'Jane Smith';
  const tUser = AppUser(
    id: 'new-user-1',
    email: tEmail,
    role: UserRole.trade,
    fullName: tName,
    isOnboardingComplete: false,
  );

  group('SignUp use case', () {
    test('returns AppUser on successful registration', () async {
      when(
        () => mockRepo.register(
          email: tEmail,
          password: tPassword,
          fullName: tName,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      final result = await signUp(
        email: tEmail,
        password: tPassword,
        fullName: tName,
      );

      expect(result, const Right<Failure, AppUser>(tUser));
      verify(
        () => mockRepo.register(
          email: tEmail,
          password: tPassword,
          fullName: tName,
        ),
      ).called(1);
    });

    test('returns AuthFailure when email is already registered', () async {
      const failure = AuthFailure('User already registered');
      when(
        () => mockRepo.register(
          email: tEmail,
          password: tPassword,
          fullName: tName,
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signUp(
        email: tEmail,
        password: tPassword,
        fullName: tName,
      );

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns ValidationFailure when password is too weak', () async {
      const failure = ValidationFailure(
        'Password must be at least 8 characters.',
      );
      when(
        () =>
            mockRepo.register(email: tEmail, password: '123', fullName: tName),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signUp(
        email: tEmail,
        password: '123',
        fullName: tName,
      );

      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns NetworkFailure when offline', () async {
      const failure = NetworkFailure();
      when(
        () => mockRepo.register(
          email: tEmail,
          password: tPassword,
          fullName: tName,
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signUp(
        email: tEmail,
        password: tPassword,
        fullName: tName,
      );

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('new user has onboarding incomplete', () async {
      when(
        () => mockRepo.register(
          email: tEmail,
          password: tPassword,
          fullName: tName,
        ),
      ).thenAnswer((_) async => const Right(tUser));

      final result = await signUp(
        email: tEmail,
        password: tPassword,
        fullName: tName,
      );

      result.fold(
        (_) => fail('Expected user'),
        (user) => expect(user.isOnboardingComplete, isFalse),
      );
    });
  });
}
