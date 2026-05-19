import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/legal_acceptance.dart';
import '../domain/legal_document.dart';

class LegalAcceptanceRepository {
  final SupabaseClient _db;

  const LegalAcceptanceRepository(this._db);

  Future<Either<String, void>> recordAcceptance({
    required LegalDocumentType type,
    required String version,
    String? appVersion,
  }) async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return left('Not authenticated');

      await _db.from('legal_acceptances').upsert({
        'user_id': userId,
        'document_type': type.dbKey,
        'document_version': version,
        'app_version': appVersion,
      });
      return right(null);
    } on PostgrestException catch (e) {
      return left(e.message);
    } catch (e) {
      return left('$e');
    }
  }

  Future<Either<String, List<LegalAcceptance>>> fetchAcceptances() async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return left('Not authenticated');

      final rows = await _db
          .from('legal_acceptances')
          .select()
          .eq('user_id', userId)
          .order('accepted_at', ascending: false);

      final acceptances = (rows as List).map((r) {
        final typeStr = r['document_type'] as String;
        final docType = typeStr == 'terms_of_service'
            ? LegalDocumentType.termsOfService
            : LegalDocumentType.privacyPolicy;
        return LegalAcceptance(
          userId: r['user_id'] as String,
          documentType: docType,
          documentVersion: r['document_version'] as String,
          acceptedAt: DateTime.parse(r['accepted_at'] as String),
          appVersion: r['app_version'] as String?,
        );
      }).toList();

      return right(acceptances);
    } on PostgrestException catch (e) {
      return left(e.message);
    } catch (e) {
      return left('$e');
    }
  }

  // Returns the version the user last accepted for each document type,
  // keyed by LegalDocumentType.dbKey.
  Future<Either<String, Map<String, String>>> lastAcceptedVersions() async {
    final result = await fetchAcceptances();
    return result.map((acceptances) {
      final map = <String, String>{};
      for (final a in acceptances) {
        // fetchAcceptances is ordered desc — first hit per type is the latest.
        map.putIfAbsent(a.documentType.dbKey, () => a.documentVersion);
      }
      return map;
    });
  }
}
