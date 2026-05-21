import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/auth/domain/entities/app_user.dart';
import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/auth/domain/repositories/auth_repository.dart';
import 'package:jobdun/features/auth/domain/usecases/sign_in.dart';
import 'package:jobdun/features/auth/domain/usecases/sign_out.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _tEmail = 'worker@jobdun.com';
const _tPassword = 'password123';
const _tUser = AppUser(id: 'user-1', email: _tEmail, role: UserRole.trade);

void main() {
  late MockAuthRepository mockRepo;
  late SignIn signIn;
  late SignOut signOut;

  setUp(() {
    mockRepo = MockAuthRepository();
    signIn = SignIn(mockRepo);
    signOut = SignOut(mockRepo);
  });

  group('Login', () {
    test('success — returns AppUser', () async {
      when(
        () => mockRepo.signIn(email: _tEmail, password: _tPassword),
      ).thenAnswer((_) async => const Right(_tUser));

      final result = await signIn(email: _tEmail, password: _tPassword);

      expect(result, const Right<Failure, AppUser>(_tUser));
    });

    test('fail — wrong password returns AuthFailure', () async {
      const failure = AuthFailure('Invalid login credentials');
      when(
        () => mockRepo.signIn(email: _tEmail, password: _tPassword),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signIn(email: _tEmail, password: _tPassword);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('fail — empty email returns AuthFailure', () async {
      const failure = AuthFailure('Email is required');
      when(
        () => mockRepo.signIn(email: '', password: _tPassword),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signIn(email: '', password: _tPassword);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('fail — empty password returns AuthFailure', () async {
      const failure = AuthFailure('Password is required');
      when(
        () => mockRepo.signIn(email: _tEmail, password: ''),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signIn(email: _tEmail, password: '');

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected failure'),
      );
    });
  });

  group('Logout', () {
    test('success — completes without error', () async {
      when(() => mockRepo.signOut()).thenAnswer((_) async => const Right(null));

      final result = await signOut();

      expect(result.isRight(), isTrue);
      verify(() => mockRepo.signOut()).called(1);
    });

    test('fail — ServerFailure on network issue', () async {
      const failure = ServerFailure('Network error');
      when(
        () => mockRepo.signOut(),
      ).thenAnswer((_) async => const Left(failure));

      final result = await signOut();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected failure'),
      );
    });
  });
}
