// hide supabase's AuthException so ours from core/errors/exceptions.dart is unambiguous
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<UserModel> signIn({required String email, required String password});
  Future<UserModel?> register({
    required String email,
    required String password,
    required String fullName,
  });
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
  Stream<UserModel?> watchAuthState();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) throw const AuthException('Sign-in failed.');
      return _fetchProfile(user.id, user.email ?? email);
    } on AuthApiException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<UserModel?> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      final user = response.user;
      if (user == null) return null; // email confirmation pending
      return UserModel(id: user.id, email: user.email ?? email, role: UserRole.trade);
    } on AuthApiException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id, user.email ?? '');
  }

  @override
  Stream<UserModel?> watchAuthState() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;
      return _fetchProfile(user.id, user.email ?? '');
    });
  }

  Future<UserModel> _fetchProfile(String userId, String email) async {
    try {
      final data = await _client
          .from('profiles')
          .select('id, display_name, avatar_url, onboarding_completed_at')
          .eq('id', userId)
          .maybeSingle();
      if (data == null) {
        return UserModel(id: userId, email: email, role: UserRole.trade);
      }
      // Role comes from JWT claim injected by custom_access_token_hook.
      // UserModel.fromJson handles 'user_role' key from JWT or defaults to trade.
      return UserModel.fromJson({...data, 'email': email});
    } catch (e, st) {
      assert(() { debugPrint('[AuthRemoteDataSource] _fetchProfile: $e\n$st'); return true; }());
      return UserModel(id: userId, email: email, role: UserRole.trade);
    }
  }
}
