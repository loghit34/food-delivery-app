import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/student/home/student_home_screen.dart';
import '../screens/vendor/dashboard/vendor_dashboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/vendor-dashboard',
        builder: (context, state) => const VendorDashboardScreen(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final isAuth = authRepo.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isSplash = state.matchedLocation == '/splash';

      if (!isAuth) {
        return isLoggingIn ? null : '/login';
      }

      // User is authenticated
      final profile = profileAsync.value;
      if (profile == null) {
        // While profile is loading from DB, keep on splash or current location
        return isLoggingIn ? '/splash' : null;
      }

      final isVendor = profile.isVendor;

      // Role-based redirection from auth/splash screens
      if (isLoggingIn || isSplash) {
        return isVendor ? '/vendor-dashboard' : '/home';
      }

      // Restrict vendor screen from student access
      if (!isVendor && state.matchedLocation.startsWith('/vendor-dashboard')) {
        return '/home';
      }

      // Restrict student screen from vendor access
      if (isVendor && state.matchedLocation.startsWith('/home')) {
        return '/vendor-dashboard';
      }

      return null;
    },
  );
});
