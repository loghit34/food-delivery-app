import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/order_provider.dart';
import 'dashboard/vendor_dashboard_screen.dart';
import 'orders/vendor_order_history_screen.dart';
import 'menu/vendor_menu_screen.dart';

class VendorMainNavScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const VendorMainNavScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<VendorMainNavScreen> createState() => _VendorMainNavScreenState();
}

class _VendorMainNavScreenState extends ConsumerState<VendorMainNavScreen> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    VendorDashboardScreen(),
    VendorOrderHistoryScreen(),
    VendorMenuManagerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(vendorOrdersProvider);
    final pendingCount = ordersAsync.value
            ?.where((o) => o.status == 'PENDING')
            .length ??
        0;

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
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.flash_on_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.flash_on),
            ),
            label: 'Live Queue',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Sales History',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Menu Manager',
          ),
        ],
      ),
    );
  }
}
