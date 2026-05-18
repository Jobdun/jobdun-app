import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';

void main() {
  group('JobFilter (T3 extensions)', () {
    test('defaults: newest sort, unpaginated, empty', () {
      const f = JobFilter();
      expect(f.sort, JobSort.newest);
      expect(f.page, isNull);
      expect(f.pageSize, 20);
      expect(f.isEmpty, isTrue);
    });

    test('isEmpty ignores pagination/sort but reflects filters', () {
      const paged = JobFilter(page: 3);
      expect(paged.isEmpty, isTrue, reason: 'pagination is not a filter');

      const filtered = JobFilter(tradeTypes: ['Electrician']);
      expect(filtered.isEmpty, isFalse);

      const budget = JobFilter(budgetMin: 50);
      expect(budget.isEmpty, isFalse);

      final start = JobFilter(startFrom: DateTime(2026, 6, 1));
      expect(start.isEmpty, isFalse);
    });

    test('copyWith(page:) preserves filters — used by paged fetch', () {
      const base = JobFilter(
        tradeTypes: ['Plumber'],
        budgetMin: 40,
        searchQuery: 'deck',
      );
      final p2 = base.copyWith(page: 2);
      expect(p2.page, 2);
      expect(p2.tradeTypes, ['Plumber']);
      expect(p2.budgetMin, 40);
      expect(p2.searchQuery, 'deck');
      expect(p2.sort, JobSort.newest);
    });

    test('clear flags null out grouped fields', () {
      const base = JobFilter(
        tradeTypes: ['Painter'],
        budgetMin: 10,
        budgetMax: 90,
        searchQuery: 'fence',
      );
      final cleared = base.copyWith(clearTradeTypes: true, clearBudget: true);
      expect(cleared.tradeTypes, isNull);
      expect(cleared.budgetMin, isNull);
      expect(cleared.budgetMax, isNull);
      // Unrelated fields survive.
      expect(cleared.searchQuery, 'fence');
    });

    test('value equality holds across the new fields', () {
      expect(
        const JobFilter(tradeType: 'x'),
        const JobFilter(tradeType: 'x'),
        reason: 'new optional fields default equally',
      );
      expect(
        const JobFilter(budgetMin: 1),
        isNot(const JobFilter(budgetMin: 2)),
      );
    });
  });
}
