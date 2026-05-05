import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/verification_document.dart';

final verificationControllerProvider =
    NotifierProvider<VerificationController, VerificationState>(
  VerificationController.new,
);

class VerificationController extends Notifier<VerificationState> {
  @override
  VerificationState build() => const VerificationState();
}

class VerificationState {
  const VerificationState({
    this.documents = const [],
    this.isLoading = false,
    this.error,
  });

  final List<VerificationDocument> documents;
  final bool isLoading;
  final String? error;

  VerificationState copyWith({
    List<VerificationDocument>? documents,
    bool? isLoading,
    String? error,
  }) =>
      VerificationState(
        documents: documents ?? this.documents,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
