import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/quotes/data/models/quote_request_model.dart';
import 'package:jobdun/features/quotes/domain/entities/quote_request.dart';

void main() {
  test('fromJson maps core fields, status, money + joined names', () {
    final m = QuoteRequestModel.fromJson({
      'id': 'q1',
      'job_id': 'j1',
      'builder_id': 'b1',
      'trade_id': 't1',
      'status': 'quoted',
      'request_note': 'Can you quote this deck?',
      'quote_amount': 1250.5,
      'response_note': 'Sure — happy to.',
      'created_at': '2026-06-10T02:00:00Z',
      'responded_at': '2026-06-10T03:00:00Z',
      'jobs': {'title': 'Deck build'},
      'builder_profiles': {'company_name': 'Acme Builders'},
      'trade_profiles': {
        'full_name': 'Jo Tradie',
        'primary_trade': 'carpenter',
      },
    });

    expect(m.id, 'q1');
    expect(m.status, QuoteRequestStatus.quoted);
    expect(m.quoteAmount, 1250.5);
    expect(m.jobTitle, 'Deck build');
    expect(m.builderCompanyName, 'Acme Builders');
    expect(m.tradeFullName, 'Jo Tradie');
    expect(m.isAwaitingResponse, isFalse);
  });

  test('a fresh request defaults to requested + awaiting response', () {
    final m = QuoteRequestModel.fromJson({
      'id': 'q1',
      'job_id': 'j1',
      'builder_id': 'b1',
      'trade_id': 't1',
      'status': 'requested',
      'created_at': '2026-06-10T02:00:00Z',
    });

    expect(m.status, QuoteRequestStatus.requested);
    expect(m.isAwaitingResponse, isTrue);
    expect(m.quoteAmount, isNull);
  });
}
