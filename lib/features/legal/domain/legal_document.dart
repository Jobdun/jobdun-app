import 'package:equatable/equatable.dart';

enum LegalDocumentType {
  termsOfService,
  privacyPolicy;

  String get assetPath => switch (this) {
    LegalDocumentType.termsOfService => 'assets/legal/terms_of_service.md',
    LegalDocumentType.privacyPolicy => 'assets/legal/privacy_policy.md',
  };

  String get dbKey => switch (this) {
    LegalDocumentType.termsOfService => 'terms_of_service',
    LegalDocumentType.privacyPolicy => 'privacy_policy',
  };

  String get displayTitle => switch (this) {
    LegalDocumentType.termsOfService => 'Terms of Service',
    LegalDocumentType.privacyPolicy => 'Privacy Policy',
  };
}

class LegalDocument extends Equatable {
  const LegalDocument({
    required this.type,
    required this.version,
    required this.content,
  });

  final LegalDocumentType type;
  final String version;
  final String content;

  @override
  List<Object?> get props => [type, version, content];
}
