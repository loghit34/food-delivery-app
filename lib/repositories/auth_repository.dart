import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../core/network/api_client.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign in with campus email & password
  Future<ProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Authentication failed: No user returned');
    }

    // Fetch corresponding profile
    return await getProfile(user.id);
  }

  /// Sign up for Student or Faculty
  /// Enforces backend profile sync
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role, // 'STUDENT' or 'FACULTY'
  }) async {
    if (role != 'STUDENT' && role != 'FACULTY') {
      throw Exception('Public registration is restricted to Students and Faculty.');
    }

    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim(), 'role': role},
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Registration failed: No user created');
    }

    // Call backend sync-profile endpoint to ensure profile row is created
    try {
      await ApiClient.post(
        '/auth/sync-profile',
        body: {
          'email': email.trim(),
          'name': name.trim(),
          'role': role,
        },
      );
    } catch (_) {
      // Backend auth middleware will auto-heal if sync call is deferred
    }
  }

  /// Get current user profile from profiles table
  Future<ProfileModel> getProfile(String userId) async {
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data != null) {
      return ProfileModel.fromJson(data);
    }

    // Fallback: fetch via backend /auth/me
    try {
      final me = await ApiClient.get('/auth/me');
      if (me is Map<String, dynamic>) {
        return ProfileModel.fromJson(me);
      }
    } catch (_) {}

    // Fallback to auth metadata
    final user = _supabase.auth.currentUser;
    final meta = user?.user_metadata ?? {};
    return ProfileModel(
      id: userId,
      name: meta['name'] ?? user?.email?.split('@')[0] ?? 'User',
      email: user?.email ?? '',
      role: meta['role'] ?? 'STUDENT',
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
