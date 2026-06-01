import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/app/placeholders/placeholder_models.dart';

void main() {
  group('placeholder enums — forward-compatible labels + defaults', () {
    test('SubscriptionTier', () {
      expect(SubscriptionTier.free.label, 'FREE');
      expect(SubscriptionTier.pro.label, 'PRO');
      expect(SubscriptionTier.placeholderDefault, SubscriptionTier.free);
    });

    test('UserModerationStatus', () {
      expect(UserModerationStatus.active.label, 'ACTIVE');
      expect(UserModerationStatus.suspended.label, 'SUSPENDED');
      expect(UserModerationStatus.banned.label, 'BANNED');
      expect(
        UserModerationStatus.placeholderDefault,
        UserModerationStatus.active,
      );
    });

    test('JobModerationStatus', () {
      expect(JobModerationStatus.active.label, 'ACTIVE');
      expect(JobModerationStatus.hidden.label, 'HIDDEN');
      expect(JobModerationStatus.removed.label, 'REMOVED');
      expect(
        JobModerationStatus.placeholderDefault,
        JobModerationStatus.active,
      );
    });
  });

  test('AdminPhase copy is the contracted wording', () {
    // The disabled moderation buttons promise this exact tooltip; a reword
    // would silently break the UX contract, so pin it.
    expect(AdminPhase.moderationWiring, 'Wiring in Phase 2 — moderation');
    expect(AdminPhase.moderation, 'Phase 2 — moderation');
    expect(AdminPhase.billing, 'Phase 3 — billing');
  });
}
