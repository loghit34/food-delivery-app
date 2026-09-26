import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/cart_provider.dart';
import 'home/student_home_screen.dart';
import 'orders/student_orders_screen.dart';
import 'cart/cart_screen.dart';

class StudentMainNavScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const StudentMainNavScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<StudentMainNavScreen> createState() => _StudentMainNavScreenState();
}

class _StudentMainNavScreenState extends ConsumerState<StudentMainNavScreen> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    StudentHomeScreen(),
    StudentOrdersScreen(),
    CartScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cartItemCount = cartState.totalItemCount;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        backgroundColor: Colors.white,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_outlined),
            activeIcon: Icon(Icons.restaurant),
            label: 'Canteens',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'My Orders',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: cartItemCount > 0,
              label: Text('$cartItemCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: cartItemCount > 0,
              label: Text('$cartItemCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}
