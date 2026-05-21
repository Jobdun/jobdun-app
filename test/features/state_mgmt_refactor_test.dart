// Tests for the state-management refactor (Sprint M1).
//
// Covers the high-risk changes from docs/STATE_MANAGEMENT_AUDIT.md:
//   • ProfileController.saveProfile now routes through ProfileRepository
//     (the repo-bypass fix) — verifies the right model fields land in upsert.
//   • The three previously-stub controllers (Notifications, Reviews,
//     Verification) actually call their repos and update state correctly.
//   • OAuthService throws StateError when GOOGLE_WEB_CLIENT_ID is missing
//     (so the AuthController's catch surfaces a user-friendly message).
//   • TradeProfileModel correctly round-trips the new `trade_other` field.
//
// Pattern: ProviderContainer + mocktail-mocked repos + an override of
// currentUserIdSyncProvider so we don't need a real Supabase init.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';

import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/auth/data/services/oauth_service.dart';

import 'package:jobdun/features/notifications/domain/entities/app_notification.dart';
import 'package:jobdun/features/notifications/domain/repositories/notification_repository.dart';
import 'package:jobdun/features/notifications/presentation/providers/notifications_provider.dart';

import 'package:jobdun/features/profile/data/models/builder_profile_model.dart';
import 'package:jobdun/features/profile/data/models/trade_profile_model.dart';
import 'package:jobdun/features/profile/data/models/user_profile_model.dart';
import 'package:jobdun/features/profile/domain/entities/builder_profile.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/repositories/profile_repository.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

import 'package:jobdun/features/reviews/domain/entities/review.dart';
import 'package:jobdun/features/reviews/domain/repositories/review_repository.dart';
import 'package:jobdun/features/reviews/presentation/providers/reviews_provider.dart';

import 'package:jobdun/features/verification/domain/entities/verification_document.dart';
import 'package:jobdun/features/verification/domain/repositories/verification_repository.dart';
import 'package:jobdun/features/verification/presentation/providers/verification_provider.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockReviewRepository extends Mock implements ReviewRepository {}

class MockVerificationRepository extends Mock
    implements VerificationRepository {}

class MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

void main() {
  setUpAll(() async {
    // AppEnv reads dotenv on every call. The dev `.env` file at the project
    // root has GOOGLE_WEB_CLIENT_ID set, which would let the "not configured"
    // guard in OAuthService.signInWithGoogle slip past. Force-empty it via
    // mergeWith so the test verifies the actual failure path.
    await dotenv.load(mergeWith: const {'GOOGLE_WEB_CLIENT_ID': ''});

    registerFallbackValue(
      const BuilderProfileModel(id: 'fallback', companyName: ''),
    );
    registerFallbackValue(
      const TradeProfileModel(id: 'fallback', fullName: '', primaryTrade: ''),
    );
    registerFallbackValue(const UserProfileModel(id: 'fallback'));
  });

  // ── ProfileController.saveProfile — the repo-bypass fix ─────────────────────
  group('ProfileController.saveProfile', () {
    late MockProfileRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockProfileRepository();
      container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdSyncProvider.overrideWithValue('user-1'),
        ],
      );
      addTearDown(container.dispose);

      // Stub the reload-after-save path (saveProfile awaits loadProfile).
      when(
        () => mockRepo.getProfile(any()),
      ).thenAnswer((_) async => Right(const UserProfileModel(id: 'user-1')));
      when(
        () => mockRepo.getBuilderProfile(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockRepo.getTradeProfile(any()),
      ).thenAnswer((_) async => const Right(null));
    });

    test(
      'BUILDER path: routes through upsertBuilderProfile (no direct Supabase)',
      () async {
        when(
          () => mockRepo.updateProfile(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockRepo.upsertBuilderProfile(any()),
        ).thenAnswer((_) async => const Right(null));

        // Seed state.profile so the updateProfile branch fires.
        final controller = container.read(profileControllerProvider.notifier);
        controller.state = const ProfileState(
          profile: UserProfileModel(id: 'user-1', displayName: 'Old Name'),
        );

        final ok = await controller.saveProfile(
          role: UserRole.builder,
          displayName: 'Acme Builders Pty',
          suburb: 'Parramatta',
          auState: 'NSW',
          postcode: '2150',
          about: 'We build stuff.',
          companyName: 'Acme Builders Pty',
          abn: '12345678901',
          contactName: 'Ken',
          contactPhone: '+61400000000',
          yearsInBusiness: 7,
          website: 'https://acme.example',
        );

        expect(ok, isTrue);

        // Verify the upsert was called with the right shape.
        final captured =
            verify(
                  () => mockRepo.upsertBuilderProfile(captureAny()),
                ).captured.single
                as BuilderProfile;
        expect(captured.id, 'user-1');
        expect(captured.companyName, 'Acme Builders Pty');
        expect(captured.abn, '12345678901');
        expect(captured.serviceSuburb, 'Parramatta');
        expect(captured.serviceState, 'NSW');
        expect(captured.servicePostcode, '2150');
        expect(captured.yearsInBusiness, 7);

        // And that we did NOT touch trade_profiles.
        verifyNever(() => mockRepo.upsertTradeProfile(any()));
      },
    );

    test(
      'TRADE path: routes through upsertTradeProfile incl. tradeOther',
      () async {
        when(
          () => mockRepo.updateProfile(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockRepo.upsertTradeProfile(any()),
        ).thenAnswer((_) async => const Right(null));

        final controller = container.read(profileControllerProvider.notifier);
        controller.state = const ProfileState(
          profile: UserProfileModel(id: 'user-1', displayName: 'Old Name'),
        );

        final ok = await controller.saveProfile(
          role: UserRole.trade,
          displayName: 'Tom the Builder',
          suburb: 'Bondi',
          auState: 'NSW',
          postcode: '2026',
          about: 'Decking specialist.',
          fullName: 'Tom the Builder',
          primaryTrade: 'other',
          tradeOther: 'Decking',
          yearsExperience: 12,
          hourlyRateMin: 80,
          hourlyRateMax: 110,
          hourlyRateVisible: true,
        );

        expect(ok, isTrue);

        final captured =
            verify(
                  () => mockRepo.upsertTradeProfile(captureAny()),
                ).captured.single
                as TradeProfile;
        expect(captured.id, 'user-1');
        expect(captured.fullName, 'Tom the Builder');
        expect(captured.primaryTrade, 'other');
        expect(captured.tradeOther, 'Decking');
        expect(captured.baseSuburb, 'Bondi');
        expect(captured.yearsExperience, 12);
        expect(captured.hourlyRateMin, 80);

        verifyNever(() => mockRepo.upsertBuilderProfile(any()));
      },
    );

    test(
      'TRADE path: clears tradeOther when primaryTrade != "other"',
      () async {
        when(
          () => mockRepo.updateProfile(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockRepo.upsertTradeProfile(any()),
        ).thenAnswer((_) async => const Right(null));

        final controller = container.read(profileControllerProvider.notifier);
        controller.state = const ProfileState(
          profile: UserProfileModel(id: 'user-1'),
        );

        await controller.saveProfile(
          role: UserRole.trade,
          displayName: 'Tom',
          suburb: 'Bondi',
          auState: 'NSW',
          postcode: '2026',
          about: null,
          fullName: 'Tom',
          primaryTrade: 'electrician',
          tradeOther: 'leftover text — should be discarded',
        );

        final captured =
            verify(
                  () => mockRepo.upsertTradeProfile(captureAny()),
                ).captured.single
                as TradeProfile;
        expect(captured.primaryTrade, 'electrician');
        expect(captured.tradeOther, isNull);
      },
    );

    test('returns false + sets error when repo upsert fails', () async {
      when(
        () => mockRepo.updateProfile(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockRepo.upsertBuilderProfile(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('RLS denied')));

      final controller = container.read(profileControllerProvider.notifier);
      controller.state = const ProfileState(
        profile: UserProfileModel(id: 'user-1'),
      );

      final ok = await controller.saveProfile(
        role: UserRole.builder,
        displayName: 'Acme',
        suburb: 'Sydney',
        auState: 'NSW',
        postcode: '2000',
        about: null,
        companyName: 'Acme',
      );

      expect(ok, isFalse);
      expect(controller.state.error, contains('RLS denied'));
      expect(controller.state.isLoading, isFalse);
    });
  });

  // ── NotificationsController — newly unstubbed ───────────────────────────────
  group('NotificationsController', () {
    late MockNotificationRepository mockRepo;
    late ProviderContainer container;

    AppNotification makeNotification({String id = 'n-1', DateTime? readAt}) =>
        AppNotification(
          id: id,
          userId: 'user-1',
          type: NotificationType.newMessage,
          title: 'Title',
          body: 'Body',
          createdAt: DateTime(2026, 5, 22),
          readAt: readAt,
        );

    setUp(() {
      mockRepo = MockNotificationRepository();
      // Empty stream so the watch in build() doesn't error.
      when(
        () => mockRepo.watchNotifications(any()),
      ).thenAnswer((_) => const Stream.empty());

      container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdSyncProvider.overrideWithValue('user-1'),
        ],
      );
      addTearDown(container.dispose);
    });

    test('load() populates state + computes unreadCount', () async {
      final rows = [
        makeNotification(id: 'n-1'),
        makeNotification(id: 'n-2', readAt: DateTime(2026, 5, 21)),
        makeNotification(id: 'n-3'),
      ];
      when(
        () => mockRepo.getNotifications('user-1'),
      ).thenAnswer((_) async => Right(rows));

      final controller = container.read(
        notificationsControllerProvider.notifier,
      );
      await controller.load();

      expect(controller.state.notifications.length, 3);
      expect(controller.state.unreadCount, 2);
      expect(controller.state.isLoading, isFalse);
    });

    test('markRead() applies optimistic update immediately', () async {
      final unread = makeNotification(id: 'n-1');
      when(
        () => mockRepo.getNotifications('user-1'),
      ).thenAnswer((_) async => Right([unread]));
      when(
        () => mockRepo.markAsRead('n-1'),
      ).thenAnswer((_) async => const Right(null));

      final controller = container.read(
        notificationsControllerProvider.notifier,
      );
      // build() schedules `Future.microtask(_loadAndWatch)` — drain it first
      // so it doesn't race with our explicit markRead. After this yield the
      // initial load is done and the stream subscription is parked on the
      // empty mock stream (no more events incoming).
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.unreadCount, 1);

      await controller.markRead('n-1');

      expect(controller.state.unreadCount, 0);
      expect(controller.state.notifications.single.isRead, isTrue);
      verify(() => mockRepo.markAsRead('n-1')).called(1);
    });
  });

  // ── ReviewsController — newly unstubbed ─────────────────────────────────────
  group('ReviewsController', () {
    late MockReviewRepository mockRepo;
    late ProviderContainer container;

    Review makeReview({String id = 'r-1', int rating = 4}) => Review(
      id: id,
      jobId: 'job-1',
      reviewerId: 'reviewer-1',
      revieweeId: 'reviewee-1',
      rating: rating,
      createdAt: DateTime(2026, 5, 22),
    );

    setUp(() {
      mockRepo = MockReviewRepository();
      container = ProviderContainer(
        overrides: [reviewRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);
    });

    test('loadFor() loads reviews + avg rating into state', () async {
      final reviews = [
        makeReview(id: 'r-1', rating: 5),
        makeReview(id: 'r-2', rating: 3),
      ];
      when(
        () => mockRepo.getReviewsForUser('reviewee-1'),
      ).thenAnswer((_) async => Right(reviews));
      when(
        () => mockRepo.getAverageRating('reviewee-1'),
      ).thenAnswer((_) async => const Right(4.0));

      final controller = container.read(reviewsControllerProvider.notifier);
      await controller.loadFor('reviewee-1');

      expect(controller.state.reviews.length, 2);
      expect(controller.state.averageRating, 4.0);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
    });
  });

  // ── VerificationController — newly unstubbed ────────────────────────────────
  group('VerificationController', () {
    late MockVerificationRepository mockRepo;
    late ProviderContainer container;

    VerificationDocument makeDoc({String id = 'd-1'}) => VerificationDocument(
      id: id,
      tradeId: 'user-1',
      docType: DocType.tradeLicence,
      filePath: 'user-1/trade_licence.pdf',
      status: VerificationStatus.pending,
      submittedAt: DateTime(2026, 5, 22),
    );

    setUp(() {
      mockRepo = MockVerificationRepository();
      when(
        () => mockRepo.watchMyDocuments(any()),
      ).thenAnswer((_) => const Stream.empty());

      container = ProviderContainer(
        overrides: [
          verificationRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdSyncProvider.overrideWithValue('user-1'),
        ],
      );
      addTearDown(container.dispose);
    });

    test('load() populates documents into state', () async {
      when(
        () => mockRepo.getMyDocuments('user-1'),
      ).thenAnswer((_) async => Right([makeDoc(), makeDoc(id: 'd-2')]));

      final controller = container.read(
        verificationControllerProvider.notifier,
      );
      await controller.load();

      expect(controller.state.documents.length, 2);
      expect(controller.state.isLoading, isFalse);
    });

    test('load() surfaces failure into state.error', () async {
      when(
        () => mockRepo.getMyDocuments('user-1'),
      ).thenAnswer((_) async => const Left(ServerFailure('bucket denied')));

      final controller = container.read(
        verificationControllerProvider.notifier,
      );
      await controller.load();

      expect(controller.state.documents, isEmpty);
      expect(controller.state.error, contains('bucket denied'));
    });
  });

  // ── OAuthService — Google misconfiguration guard ────────────────────────────
  group('OAuthService.signInWithGoogle', () {
    test('throws StateError when GOOGLE_WEB_CLIENT_ID is missing', () async {
      // AppEnv.isGoogleConfigured reads dotenv at runtime — in the default
      // test runner it's empty, so this path fires before any SDK call.
      final service = OAuthService(MockSupabaseClient());
      expect(
        service.signInWithGoogle(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('GOOGLE_WEB_CLIENT_ID'),
          ),
        ),
      );
    });
  });

  // ── TradeProfileModel — new trade_other round-trip ──────────────────────────
  group('TradeProfileModel', () {
    test('round-trips trade_other through fromJson + toJson', () {
      final json = {
        'id': 'user-1',
        'full_name': 'Tom',
        'primary_trade': 'other',
        'trade_other': 'Decking specialist',
        'base_suburb': 'Bondi',
      };

      final model = TradeProfileModel.fromJson(json);
      expect(model.tradeOther, 'Decking specialist');

      final serialised = model.toJson();
      expect(serialised['trade_other'], 'Decking specialist');
      expect(serialised['primary_trade'], 'other');
    });

    test('trade_other is null when DB column is null', () {
      final json = {
        'id': 'user-1',
        'full_name': 'Sparky Bob',
        'primary_trade': 'electrician',
      };

      final model = TradeProfileModel.fromJson(json);
      expect(model.tradeOther, isNull);
      expect(model.toJson()['trade_other'], isNull);
    });
  });
}
