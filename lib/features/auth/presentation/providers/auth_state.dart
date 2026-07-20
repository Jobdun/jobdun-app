import '../../domain/entities/user_role.dart';

// Snapshot of what the user entered at /register — held in AuthState so the
// "Wrong email? Change it" affordance on /verify-email can return them to
// step 2 of /register with the form pre-filled instead of starting over.
class RegisterDraft {
  const RegisterDraft({required this.fullName, required this.email, this.role});

  final String fullName;
  final String email;
  final UserRole? role;
}

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    // Goes true once we've actually tried to read role from the JWT/DB.
    // Distinguishes "role is null because user hasn't picked" from "role is
    // null because the load hasn't finished yet" — drives OnboardingCompletionSheet.
    this.isRoleLoaded = false,
    this.role,
    this.email,
    this.pendingVerificationEmail,
    this.pendingPhoneNumber,
    this.registerDraft,
    this.errorMessage,
    this.infoMessage,
    // True when any linked identity (Apple/Google) supplied the user's name
    // at auth time — the onboarding flow must never re-ask for it (G4).
    this.ssoNameProvider = false,
    this.metadataDisplayName,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final bool isRoleLoaded;
  final UserRole? role;
  final String? email;
  final String? pendingVerificationEmail;
  final String? pendingPhoneNumber;
  final RegisterDraft? registerDraft;
  final String? errorMessage;
  final String? infoMessage;
  final bool ssoNameProvider;
  final String? metadataDisplayName;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isRoleLoaded,
    UserRole? role,
    String? email,
    String? pendingVerificationEmail,
    String? pendingPhoneNumber,
    RegisterDraft? registerDraft,
    String? errorMessage,
    String? infoMessage,
    bool? ssoNameProvider,
    String? metadataDisplayName,
    bool clearRole = false,
    bool clearPendingVerification = false,
    bool clearPhone = false,
    bool clearRegisterDraft = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isRoleLoaded: isRoleLoaded ?? this.isRoleLoaded,
      role: clearRole ? null : role ?? this.role,
      email: email ?? this.email,
      pendingVerificationEmail: clearPendingVerification
          ? null
          : pendingVerificationEmail ?? this.pendingVerificationEmail,
      pendingPhoneNumber: clearPhone
          ? null
          : pendingPhoneNumber ?? this.pendingPhoneNumber,
      registerDraft: clearRegisterDraft
          ? null
          : registerDraft ?? this.registerDraft,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      ssoNameProvider: ssoNameProvider ?? this.ssoNameProvider,
      metadataDisplayName: metadataDisplayName ?? this.metadataDisplayName,
    );
  }
}
