import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/student/student_main_nav_screen.dart';
import '../screens/student/menu/vendor_menu_screen.dart';
import '../screens/student/cart/cart_screen.dart';
import '../screens/student/checkout/checkout_screen.dart';
import '../screens/student/payment/payment_success_screen.dart';
import '../screens/vendor/vendor_main_nav_screen.dart';
import '../screens/admin/admin_main_nav_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      // Splash & Auth
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

      // Student Flow
      GoRoute(
        path: '/home',
        builder: (context, state) => const StudentMainNavScreen(initialIndex: 0),
      ),
      GoRoute(
        path: '/my-orders',
        builder: (context, state) => const StudentMainNavScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const StudentMainNavScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/menu/:vendorId',
        builder: (context, state) {
          final vendorId = state.pathParameters['vendorId'] ?? '';
          return VendorMenuScreen(vendorId: vendorId);
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/payment-success',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final orderId = extra?['orderId'] ??
              state.uri.queryParameters['orderId'] ??
              '';
          final dailyNum = extra?['dailyNum'] ??
              state.uri.queryParameters['dailyNum'] ??
              '1';
          final status = extra?['status'] ??
              state.uri.queryParameters['status'] ??
              'PENDING';
          return PaymentSuccessScreen(
            orderId: orderId.toString(),
            dailyNum: dailyNum.toString(),
            orderStatus: status.toString(),
          );
        },
      ),

      // Vendor Flow
      GoRoute(
        path: '/vendor',
        builder: (context, state) => const VendorMainNavScreen(initialIndex: 0),
      ),
      GoRoute(
        path: '/vendor-dashboard',
        redirect: (context, state) => '/vendor',
      ),
      GoRoute(
        path: '/vendor/orders',
        builder: (context, state) => const VendorMainNavScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/vendor/menu',
        builder: (context, state) => const VendorMainNavScreen(initialIndex: 2),
      ),

      // Admin Flow
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminMainNavScreen(initialIndex: 0),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminMainNavScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/admin/vendors',
        builder: (context, state) => const AdminMainNavScreen(initialIndex: 2),
      ),
      GoRoute(
        path: '/admin/orders',
        builder: (context, state) => const AdminMainNavScreen(initialIndex: 3),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final isAuth = authRepo.currentUser != null;
      final loc = state.matchedLocation;
      final isLoggingIn = loc == '/login' || loc == '/register';
      final isSplash = loc == '/splash';

      if (!isAuth) {
        return isLoggingIn ? null : '/login';
      }

      // User is authenticated
      final profile = profileAsync.value;
      if (profile == null) {
        // While profile is loading from DB, keep on splash or current location
        return isLoggingIn ? '/splash' : null;
      }

      // Role-based redirection from auth/splash screens
      if (isLoggingIn || isSplash) {
        if (profile.isAdmin) return '/admin';
        if (profile.isVendor) return '/vendor';
        return '/home';
      }

      // Restrict admin routes
      if (loc.startsWith('/admin')) {
        if (!profile.isAdmin) {
          return profile.isVendor ? '/vendor' : '/home';
        }
      }

      // Restrict vendor routes
      if (loc.startsWith('/vendor')) {
        if (!profile.isVendor) {
          return profile.isAdmin ? '/admin' : '/home';
        }
      }

      // Restrict student vendor menu and checkout from vendor accounts
      if (profile.isVendor && (loc == '/checkout' || loc == '/cart')) {
        return '/vendor';
      }

      return null;
    },
  );
});
