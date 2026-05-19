import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';

import '../domain/legal_document.dart';

class LegalDocumentRepository {
  Future<Either<String, LegalDocument>> load(LegalDocumentType type) async {
    try {
      final versionsJson = await rootBundle.loadString(
        'assets/legal/versions.json',
      );
      final versions = json.decode(versionsJson) as Map<String, dynamic>;
      final version = versions[type.dbKey] as String? ?? '1.0.0';
      final content = await rootBundle.loadString(type.assetPath);
      return right(
        LegalDocument(type: type, version: version, content: content),
      );
    } catch (e) {
      return left('Failed to load ${type.displayTitle}: $e');
    }
  }

  Future<Either<String, Map<String, String>>> versions() async {
    try {
      final raw = await rootBundle.loadString('assets/legal/versions.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return right(decoded.map((k, v) => MapEntry(k, v.toString())));
    } catch (e) {
      return left('Failed to load versions: $e');
    }
  }
}
