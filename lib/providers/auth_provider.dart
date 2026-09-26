import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../models/profile_model.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthRepository(supabase);
});

/// Watches live Supabase Auth session changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

/// Fetches and caches current user's profile
final userProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = authRepo.currentUser;
  if (user == null) return null;
  return await authRepo.getProfile(user.id);
});

/// State controller for login / registration operations
class AuthController extends StateNotifier<AsyncValue<ProfileModel?>> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthController(this._authRepository, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authRepository.signIn(
        email: email,
        password: password,
      );
      _ref.invalidate(userProfileProvider);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signUp(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _ref.invalidate(userProfileProvider);
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<ProfileModel?>>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AuthController(authRepo, ref);
});
