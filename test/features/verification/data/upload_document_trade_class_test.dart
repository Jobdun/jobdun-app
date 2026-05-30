import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/verification/data/repositories/verification_repository_impl.dart';
import 'package:jobdun/features/verification/data/datasources/verification_remote_datasource.dart';
import 'package:jobdun/features/verification/data/models/verification_document_model.dart';
import 'package:jobdun/features/verification/domain/entities/verification_document.dart';
import 'package:jobdun/features/verification/domain/usecases/upload_document.dart';

// NOTE: UNRUN — written TDD-first; the orchestrator runs the suite afterward.

// Captures the tradeClass argument so we can prove the value threads all the
// way from the use case → repo → datasource (frozen contract #1).
class _CapturingDatasource implements VerificationRemoteDataSource {
  String? capturedTradeClass;
  bool tradeClassSeen = false;

  @override
  Future<VerificationDocumentModel> uploadDocument({
    required String tradeId,
    required DocType docType,
    required File file,
    String? state,
    String? issuer,
    String? documentNumber,
    DateTime? issuedDate,
    DateTime? expiryDate,
    String? tradeClass,
  }) async {
    tradeClassSeen = true;
    capturedTradeClass = tradeClass;
    return VerificationDocumentModel(
      id: 'd1',
      tradeId: tradeId,
      docType: docType,
      filePath: 'p',
      status: VerificationStatus.pending,
      submittedAt: DateTime(2026, 5, 30),
    );
  }

  @override
  Future<List<VerificationDocumentModel>> getMyDocuments(
    String tradeId,
  ) async => const [];

  @override
  Future<void> softDeleteDocument(String documentId) async {}

  @override
  Stream<List<VerificationDocumentModel>> watchMyDocuments(String tradeId) =>
      const Stream.empty();
}

void main() {
  test(
    'UploadDocument forwards tradeClass through repo + datasource',
    () async {
      final ds = _CapturingDatasource();
      final repo = VerificationRepositoryImpl(ds);
      final usecase = UploadDocument(repo);

      final result = await usecase.call(
        tradeId: 'u1',
        docType: DocType.tradeLicence,
        file: File('does-not-need-to-exist.jpg'),
        state: 'NSW',
        tradeClass: 'Electrician',
      );

      expect(result.isRight(), isTrue);
      expect(ds.tradeClassSeen, isTrue);
      expect(ds.capturedTradeClass, 'Electrician');
    },
  );

  test(
    'UploadDocument leaves tradeClass null for an ABN certificate',
    () async {
      final ds = _CapturingDatasource();
      final repo = VerificationRepositoryImpl(ds);
      final usecase = UploadDocument(repo);

      final Either<Failure, VerificationDocument> result = await usecase.call(
        tradeId: 'u1',
        docType: DocType.abnCertificate,
        file: File('x.jpg'),
        // tradeClass omitted — ABN uploads carry none.
      );

      expect(result.isRight(), isTrue);
      expect(ds.capturedTradeClass, isNull);
    },
  );
}
