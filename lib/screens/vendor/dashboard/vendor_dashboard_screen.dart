import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/vendor_provider.dart';
import '../../../widgets/common/async_value_widget.dart';

class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  ConsumerState<VendorDashboardScreen> createState() =>
      _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen> {
  String _selectedTab = 'PENDING'; // 'PENDING' | 'COMPLETED'
  String _selectedRoleFilter = 'ALL'; // 'ALL' | 'STUDENT' | 'FACULTY'
  bool _soundEnabled = true;
  Timer? _pollingTimer;
  Set<String> _previousPendingOrderIds = {};
  bool _isInitialLoad = true;

  String _getTodayIST() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.invalidate(vendorOrdersProvider);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _checkNewIncomingOrders(List<OrderModel> orders) {
    final currentPending = orders
        .where((o) => o.status == 'PENDING')
        .map((o) => o.id)
        .toSet();

    if (!_isInitialLoad && _previousPendingOrderIds.isNotEmpty) {
      final hasNew = currentPending.difference(_previousPendingOrderIds).isNotEmpty;
      if (hasNew) {
        if (_soundEnabled) {
          SystemSound.play(SystemSoundType.alert);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔔 New incoming order received!'),
                backgroundColor: AppColors.primary,
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }

    _isInitialLoad = false;
    _previousPendingOrderIds = currentPending;
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myVendorStoreProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);

    ordersAsync.whenData((orders) => _checkNewIncomingOrders(orders));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: storeAsync.when(
          data: (store) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store?.vendorName ?? 'Vendor Portal',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              if (store?.location != null)
                Text(
                  store!.location!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
            ],
          ),
          loading: () => const Text('Loading Stall...'),
          error: (_, __) => const Text('Vendor Dashboard'),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _soundEnabled ? Icons.volume_up : Icons.volume_off,
              color: _soundEnabled ? AppColors.primary : AppColors.textMuted,
            ),
            tooltip: _soundEnabled ? 'Mute Chime' : 'Enable Chime',
            onPressed: () {
              setState(() => _soundEnabled = !_soundEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_soundEnabled ? '🔔 Order chime enabled' : '🔕 Order chime muted'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.secondary),
            tooltip: 'Refresh Orders',
            onPressed: () => ref.invalidate(vendorOrdersProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textMuted),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vendorOrdersProvider);
          ref.invalidate(myVendorStoreProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab Toggle Buttons (Incoming Orders vs Completed Today)
              Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      title: '⏳ Incoming Orders',
                      tabValue: 'PENDING',
                      badgeCount: ordersAsync.value
                              ?.where((o) => o.status == 'PENDING')
                              .length ??
                          0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      title: '✅ Completed',
                      tabValue: 'COMPLETED',
                      badgeCount: ordersAsync.value
                              ?.where((o) =>
                                  o.status == 'COMPLETED' &&
                                  (o.orderDate == _getTodayIST() ||
                                      (o.createdAt != null &&
                                          o.createdAt!
                                                  .toUtc()
                                                  .add(const Duration(hours: 5, minutes: 30))
                                                  .toIso8601String()
                                                  .substring(0, 10) ==
                                              _getTodayIST())))
                              .length ??
                          0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Role Filter Pills (ALL / STUDENT / FACULTY)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRolePill('ALL', 'All Orders'),
                    const SizedBox(width: 8),
                    _buildRolePill('STUDENT', 'Students'),
                    const SizedBox(width: 8),
                    _buildRolePill('FACULTY', 'Faculty'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Orders List
              AsyncValueWidget<List<OrderModel>>(
                value: ordersAsync,
                onRetry: () => ref.invalidate(vendorOrdersProvider),
                data: (allOrders) {
                  final todayIST = _getTodayIST();
                  var filtered = allOrders.where((o) {
                    if (_selectedTab == 'PENDING') {
                      return o.status == 'PENDING';
                    } else {
                      if (o.status != 'COMPLETED') return false;
                      final oDate = o.orderDate ??
                          (o.createdAt != null
                              ? o.createdAt!
                                  .toUtc()
                                  .add(const Duration(hours: 5, minutes: 30))
                                  .toIso8601String()
                                  .substring(0, 10)
                              : '');
                      return oDate == todayIST;
                    }
                  }).toList();

                  if (_selectedRoleFilter != 'ALL') {
                    filtered = filtered.where((o) {
                      final role = o.customer?.role.toUpperCase() ?? 'STUDENT';
                      return role == _selectedRoleFilter;
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Column(
                          children: [
                            Text(
                              _selectedTab == 'PENDING' ? '🎉' : '📋',
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedTab == 'PENDING'
                                  ? 'No Pending Orders'
                                  : 'No Completed Orders Yet',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedTab == 'PENDING'
                                  ? 'All orders have been prepared and collected!'
                                  : 'Orders collected by customers will appear here.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return _buildKitchenTicket(order);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required String tabValue,
    required int badgeCount,
  }) {
    final isSelected = _selectedTab == tabValue;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tabValue),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePill(String role, String label) {
    final isSelected = _selectedRoleFilter == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildKitchenTicket(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Daily Order # and Role Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.displayOrderNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (order.customer?.role != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.customer!.role,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormatter.formatTimeAgo(order.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer Name
            if (order.customer?.name != null && order.customer!.name.isNotEmpty)
              Text(
                'Customer: ${order.customer!.name}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            const Divider(height: 20),

            // Items List
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.itemName}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.format(item.price * item.quantity),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 16),

            // Footer: Paid amount (strictly vendor payable food amount, excluding platform fee)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'PAID ONLINE (Razorpay)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(order.vendorAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
