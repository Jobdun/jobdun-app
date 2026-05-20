// hide supabase's AuthException so ours from core/errors/exceptions.dart is unambiguous
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../models/user_model.dart';

// NOTE: there is no `register` method on this datasource. The live signup
// path is AuthController.register in lib/features/auth/presentation/providers/
// auth_provider.dart, which talks to SupabaseConfig.client.auth.signUp
// directly and supplies the chosen UserRole in raw_user_meta_data. Adding a
// no-role register() method back here would reintroduce the silent-default-
// to-trade bug fixed by migration 20260512000002.
abstract interface class AuthRemoteDataSource {
  Future<UserModel> signIn({required String email, required String password});
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
      assert(() {
        debugPrint('[AuthRemoteDataSource] _fetchProfile: $e\n$st');
        return true;
      }());
      return UserModel(id: userId, email: email, role: UserRole.trade);
    }
  }
}
