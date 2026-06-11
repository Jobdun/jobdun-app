import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/features/admin_verifications/presentation/providers/admin_verifications_provider.dart';
import 'package:jobdun/admin/features/admin_verifications/presentation/widgets/admin_verification_queue_row.dart';

// The admin queue lets a reviewer triage by credential type. White Card and
// public liability now have their own chips (previously lumped into "Other").
AdminVerificationItem _item(
  String docType,
  AdminVerificationKind kind, {
  String status = 'pending',
  DateTime? submittedAt,
}) => AdminVerificationItem(
  id: 'doc-$docType-$status-${submittedAt?.day ?? 0}',
  tradeId: 't1',
  docType: docType,
  kind: kind,
  status: status,
  submittedAt: submittedAt ?? DateTime(2026, 6, 10),
  filePath: 'p',
);

void main() {
  final state = AdminVerificationsState(
    items: [
      _item('trade_licence', AdminVerificationKind.tradeLicence),
      _item('abn_certificate', AdminVerificationKind.builderAbn),
      _item('white_card', AdminVerificationKind.whiteCard),
      _item('public_liability', AdminVerificationKind.publicLiability),
      _item('photo_id', AdminVerificationKind.other),
    ],
    filter: AdminVerificationKindFilter.all,
  );

  test('the White Card filter isolates White Card docs', () {
    final filtered = state
        .copyWith(filter: AdminVerificationKindFilter.whiteCard)
        .filteredItems;
    expect(filtered.single.docType, 'white_card');
  });

  test('the Insurance filter isolates public-liability docs', () {
    final filtered = state
        .copyWith(filter: AdminVerificationKindFilter.publicLiability)
        .filteredItems;
    expect(filtered.single.docType, 'public_liability');
  });

  test('counts are per-kind', () {
    expect(state.countFor(AdminVerificationKindFilter.whiteCard), 1);
    expect(state.countFor(AdminVerificationKindFilter.publicLiability), 1);
    expect(state.countFor(AdminVerificationKindFilter.all), 5);
    // photo_id stays in Other now that White Card / PL have their own chips.
    expect(state.countFor(AdminVerificationKindFilter.other), 1);
  });

  // U4.2: the 24 h SLA means the oldest pending doc is the most urgent —
  // pending sorts oldest-first; reviewed history stays newest-first.
  test('pending items sort oldest-first, reviewed newest-first', () {
    final sorted = AdminVerificationsState(
      items: [
        _item(
          'trade_licence',
          AdminVerificationKind.tradeLicence,
          submittedAt: DateTime(2026, 6, 9),
        ),
        _item(
          'white_card',
          AdminVerificationKind.whiteCard,
          submittedAt: DateTime(2026, 6, 7),
        ),
        _item(
          'abn_certificate',
          AdminVerificationKind.builderAbn,
          status: 'approved',
          submittedAt: DateTime(2026, 6, 1),
        ),
        _item(
          'public_liability',
          AdminVerificationKind.publicLiability,
          status: 'rejected',
          submittedAt: DateTime(2026, 6, 5),
        ),
      ],
      filter: AdminVerificationKindFilter.all,
    ).filteredItems;

    final pending = sorted.where((i) => i.status == 'pending').toList();
    final reviewed = sorted.where((i) => i.status != 'pending').toList();
    expect(pending.first.docType, 'white_card'); // oldest pending leads
    expect(pending.last.docType, 'trade_licence');
    expect(reviewed.first.docType, 'public_liability'); // newest reviewed
    expect(reviewed.last.docType, 'abn_certificate');
  });

  // U4.1: time-in-queue thresholds — amber from 18 h, breached past 24 h.
  test('queueAgeFor maps durations to triage buckets', () {
    expect(queueAgeFor(const Duration(hours: 4)), QueueAge.fresh);
    expect(queueAgeFor(const Duration(hours: 17, minutes: 59)), QueueAge.fresh);
    expect(queueAgeFor(const Duration(hours: 18)), QueueAge.warning);
    expect(queueAgeFor(const Duration(hours: 23)), QueueAge.warning);
    expect(queueAgeFor(const Duration(hours: 24)), QueueAge.breached);
    expect(queueAgeFor(const Duration(hours: 48)), QueueAge.breached);
  });

  test('queueAgeLabel renders hours (or minutes under an hour)', () {
    expect(queueAgeLabel(const Duration(minutes: 40)), '40 min in queue');
    expect(queueAgeLabel(const Duration(hours: 22)), '22 h in queue');
    expect(
      queueAgeLabel(const Duration(hours: 26, minutes: 30)),
      '26 h in queue',
    );
  });
}
