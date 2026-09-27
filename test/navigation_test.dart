import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uem_eats/models/profile_model.dart';
import 'package:uem_eats/providers/auth_provider.dart';
import 'package:uem_eats/providers/order_provider.dart';
import 'package:uem_eats/providers/vendor_provider.dart';
import 'package:uem_eats/providers/admin_provider.dart';
import 'package:uem_eats/routing/app_router.dart';
import 'package:uem_eats/screens/auth/login_screen.dart';
import 'package:uem_eats/screens/auth/register_screen.dart';
import 'package:uem_eats/screens/splash/splash_screen.dart';
import 'package:uem_eats/screens/student/student_main_nav_screen.dart';
import 'package:uem_eats/screens/admin/admin_main_nav_screen.dart';
import 'package:uem_eats/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mock AuthRepository for testing navigation flows
class MockAuthRepository implements AuthRepository {
  User? _user;
  ProfileModel? _profile;

  MockAuthRepository({User? user, ProfileModel? profile})
      : _user = user,
        _profile = profile;

  @override
  User? get currentUser => _user;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<ProfileModel> signIn({required String email, required String password}) async {
    return _profile ??
        ProfileModel(
          id: 'mock-user-id',
          name: 'Test Student',
          email: email,
          role: 'STUDENT',
        );
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {}

  @override
  Future<ProfileModel> getProfile(String userId) async {
    return _profile ??
        ProfileModel(
          id: userId,
          name: 'Test Student',
          email: 'student@uem.edu.in',
          role: 'STUDENT',
        );
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _profile = null;
  }
}

void main() {
  group('Sign-Up Navigation and Auth Routing Tests', () {
    testWidgets('Fresh launch starts at Splash and navigates to Login when logged out', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final profileCompleter = Completer<ProfileModel?>();
      final mockAuth = MockAuthRepository(user: null, profile: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            userProfileProvider.overrideWith((ref) => profileCompleter.future),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      // Initial frame is at /splash while profile is loading
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Complete profile check (logged out -> returns null)
      profileCompleter.complete(null);
      await tester.pumpAndSettle();

      // Now on LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('Fresh launch starts at Splash and navigates to Dashboard for authenticated user', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final profileCompleter = Completer<ProfileModel?>();
      final mockUser = const User(
        id: 'student-1',
        appMetadata: {},
        userMetadata: {'name': 'Alex Student', 'role': 'STUDENT'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
      final studentProfile = ProfileModel(
        id: 'student-1',
        name: 'Alex Student',
        email: 'alex@uem.edu.in',
        role: 'STUDENT',
      );
      final mockAuth = MockAuthRepository(user: mockUser, profile: studentProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            userProfileProvider.overrideWith((ref) => profileCompleter.future),
            activeVendorsProvider.overrideWith((ref) async => []),
            customerOrdersProvider.overrideWith((ref) async => []),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      // Initial frame is at /splash while profile loads
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(StudentMainNavScreen), findsNothing);

      // Complete profile loading
      profileCompleter.complete(studentProfile);
      await tester.pumpAndSettle();

      // Directly on Student dashboard
      expect(find.byType(StudentMainNavScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('Login -> Sign Up navigates directly to RegisterScreen without showing SplashScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockAuthRepository(user: null, profile: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            userProfileProvider.overrideWith((ref) async => null),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      // Tap Sign Up link
      final signUpButton = find.text('Sign Up');
      expect(signUpButton, findsOneWidget);
      await tester.ensureVisible(signUpButton);
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      // Should directly show RegisterScreen and never SplashScreen
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('Sign Up -> Login (via back arrow or Sign In text) navigates directly to LoginScreen without SplashScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockAuthRepository(user: null, profile: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            userProfileProvider.overrideWith((ref) async => null),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Go to Register screen
      final signUpBtn = find.text('Sign Up');
      await tester.ensureVisible(signUpBtn);
      await tester.tap(signUpBtn);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      // Tap Sign In link
      final signInLink = find.text('Sign In');
      expect(signInLink, findsOneWidget);
      await tester.ensureVisible(signInLink);
      await tester.tap(signInLink);
      await tester.pumpAndSettle();

      // Should directly show LoginScreen, never SplashScreen
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);

      // Go back to Register screen again
      final signUpBtn2 = find.text('Sign Up');
      await tester.ensureVisible(signUpBtn2);
      await tester.tap(signUpBtn2);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      // Test back arrow in AppBar
      final backArrow = find.byIcon(Icons.arrow_back);
      expect(backArrow, findsOneWidget);
      await tester.tap(backArrow);
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Role-based routing directs Admin to admin dashboard', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminProfile = ProfileModel(
        id: 'admin-1',
        name: 'Campus Admin',
        email: 'admin@uem.edu.in',
        role: 'ADMIN',
      );
      final mockUser = const User(
        id: 'admin-1',
        appMetadata: {},
        userMetadata: {'name': 'Campus Admin', 'role': 'ADMIN'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
      final mockAuth = MockAuthRepository(user: mockUser, profile: adminProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            userProfileProvider.overrideWith((ref) async => adminProfile),
            adminUsersProvider.overrideWith((ref) async => []),
            adminVendorsProvider.overrideWith((ref) async => []),
            adminOrdersProvider.overrideWith((ref) async => []),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AdminMainNavScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('Supabase profile error displays error message, Sign Out, and Retry buttons without infinite redirect loop', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockUser = const User(
        id: 'student-err-1',
        appMetadata: {},
        userMetadata: {'name': 'Error Student', 'role': 'STUDENT'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
      final mockAuth = MockAuthRepository(user: mockUser, profile: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            userProfileProvider.overrideWith((ref) => Future.error(
              const PostgrestException(
                message: 'infinite recursion detected in policy for relation "profiles"',
                code: '42P17',
              ),
            )),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Confirms SplashScreen remains visible rendering the error rather than hanging in a blank loop
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Failed to Load Profile'), findsOneWidget);
      expect(find.textContaining('infinite recursion detected in policy for relation "profiles"'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}

