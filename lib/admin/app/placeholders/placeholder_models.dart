/// Forward-compatible models for admin moderation + billing surfaces that ship
/// **UI-only** in this scaffold. The enum *values* mirror the columns we will
/// add to the schema in later phases, so wiring later is a matter of mapping a
/// real column onto these enums — not redrawing the UI.
///
/// NOTHING here touches the backend. No migration, RPC, or query references
/// these yet; every consumer hard-codes the [placeholderDefault] below and the
/// surface is rendered through the muted [AdminStatusTag] /
/// [AdminPlaceholderAction] so it can never be mistaken for live data.
library;

/// Trade subscription entitlement (business model Archetype A — trade subs).
/// Wires up in Phase 3 (billing / read-only tier visibility).
enum SubscriptionTier {
  free,
  pro;

  /// Shown everywhere until billing is wired (Phase 3).
  static const SubscriptionTier placeholderDefault = SubscriptionTier.free;

  String get label => switch (this) {
    SubscriptionTier.free => 'FREE',
    SubscriptionTier.pro => 'PRO',
  };
}

/// Account moderation state — distinct from auth/verification status. Wires up
/// in Phase 2 (moderation).
enum UserModerationStatus {
  active,
  suspended,
  banned;

  static const UserModerationStatus placeholderDefault =
      UserModerationStatus.active;

  String get label => switch (this) {
    UserModerationStatus.active => 'ACTIVE',
    UserModerationStatus.suspended => 'SUSPENDED',
    UserModerationStatus.banned => 'BANNED',
  };
}

/// Job moderation state — distinct from the job *lifecycle* status
/// (draft/open/filled/…). Wires up in Phase 2 (moderation).
enum JobModerationStatus {
  active,
  hidden,
  removed;

  static const JobModerationStatus placeholderDefault =
      JobModerationStatus.active;

  String get label => switch (this) {
    JobModerationStatus.active => 'ACTIVE',
    JobModerationStatus.hidden => 'HIDDEN',
    JobModerationStatus.removed => 'REMOVED',
  };
}

/// Phase tags surfaced in placeholder tooltips + eyebrows so every not-yet-wired
/// surface states *when* it lights up. Keep these in lock-step with the roadmap.
abstract final class AdminPhase {
  const AdminPhase._();

  /// Eyebrow / tooltip suffix for moderation surfaces.
  static const String moderation = 'Phase 2 — moderation';

  /// Eyebrow / tooltip suffix for billing surfaces.
  static const String billing = 'Phase 3 — billing';

  /// Tooltip copy for the disabled Suspend/Ban/Hide/Remove actions.
  static const String moderationWiring = 'Wiring in Phase 2 — moderation';

  // ── Stage 1 roadmap (docs/STAGE1_COMPLETION_PLAN.md) — placeholder pages ──
  // (The REPORTS slot was repurposed into the live BROADCAST page — push
  //  program Stream A — so its roadmap tags were removed.)
  /// Payments admin milestone tag.
  static const String payments = 'Stage 1 · M5 — payments rail';

  /// Disabled-action tooltip on the Payments placeholder page.
  static const String paymentsWiring = 'Wiring in M5 — payments rail';
}
