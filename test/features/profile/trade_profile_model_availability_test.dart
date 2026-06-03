import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/data/models/trade_profile_model.dart';

void main() {
  test('fromJson maps is_available + available_from', () {
    final m = TradeProfileModel.fromJson({
      'id': 't1',
      'full_name': 'Bob',
      'primary_trade': 'electrician',
      'is_available': false,
      'available_from': '2026-07-01',
    });
    expect(m.isAvailable, isFalse);
    expect(m.availableFrom, DateTime(2026, 7, 1));
  });

  test('fromJson defaults isAvailable to true when absent', () {
    final m = TradeProfileModel.fromJson({
      'id': 't1',
      'full_name': 'Bob',
      'primary_trade': 'electrician',
    });
    expect(m.isAvailable, isTrue);
    expect(m.availableFrom, isNull);
  });

  test('toJson emits availability when set', () {
    const m = TradeProfileModel(
      id: 't1',
      fullName: 'Bob',
      primaryTrade: 'electrician',
      isAvailable: false,
    );
    expect(m.toJson()['is_available'], isFalse);
  });
}
