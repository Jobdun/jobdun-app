import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Resolve applicant identity on cold job deep links, before choosing a form.
/// A failed/missing profile is unknown, never silently a qualified trade.
final jobApplicantIsApprenticeProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final userId = ref.watch(currentUserIdSyncProvider);
  if (userId == null) throw StateError('Sign in to load your profile.');
  final result = await ref
      .read(profileRepositoryProvider)
      .getTradeProfile(userId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (profile) =>
        profile?.isApprentice ??
        (throw StateError('Complete your trade profile before applying.')),
  );
});
