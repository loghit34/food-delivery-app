import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/order_model.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/vendor_provider.dart';
import '../../../widgets/common/async_value_widget.dart';

class VendorOrderHistoryScreen extends ConsumerStatefulWidget {
  const VendorOrderHistoryScreen({super.key});

  @override
  ConsumerState<VendorOrderHistoryScreen> createState() =>
      _VendorOrderHistoryScreenState();
}

class _VendorOrderHistoryScreenState
    extends ConsumerState<VendorOrderHistoryScreen> {
  String _roleFilter = 'ALL'; // 'ALL' | 'STUDENT' | 'FACULTY'

  String _getTodayIST() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatDateHeader(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final d = DateTime(year, month, day);
        return DateFormat('d MMM yyyy').format(d).toUpperCase();
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myVendorStoreProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);

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
              const Text(
                'Order & Sales History',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Order History'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh History',
            onPressed: () => ref.invalidate(vendorOrdersProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorOrdersProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role Filter Pills
              Row(
                children: [
                  _buildRoleFilterPill('ALL', 'All Orders'),
                  const SizedBox(width: 8),
                  _buildRoleFilterPill('STUDENT', 'Students'),
                  const SizedBox(width: 8),
                  _buildRoleFilterPill('FACULTY', 'Faculty'),
                ],
              ),
              const SizedBox(height: 16),

              AsyncValueWidget<List<OrderModel>>(
                value: ordersAsync,
                onRetry: () => ref.invalidate(vendorOrdersProvider),
                data: (allOrders) {
                  // Filter completed orders
                  var completed = allOrders
                      .where((o) => o.status == 'COMPLETED' || o.status == 'PAID')
                      .toList();

                  if (_roleFilter != 'ALL') {
                    completed = completed.where((o) {
                      final role = o.customer?.role.toUpperCase() ?? 'STUDENT';
                      return role == _roleFilter;
                    }).toList();
                  }

                  if (completed.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48.0),
                        child: Column(
                          children: [
                            Text('📜', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text(
                              'No Completed Orders in History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'All completed orders are permanently preserved here by date.',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Group by date
                  final Map<String, List<OrderModel>> dateGroups = {};
                  for (final order in completed) {
                    final oDate = order.orderDate ??
                        (order.createdAt != null
                            ? order.createdAt!
                                .toUtc()
                                .add(const Duration(hours: 5, minutes: 30))
                                .toIso8601String()
                                .substring(0, 10)
                            : 'Unknown Date');

                    dateGroups.putIfAbsent(oDate, () => []).add(order);
                  }

                  // Sort dates descending
                  final sortedDates = dateGroups.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  final todayIST = _getTodayIST();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedDates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final dateKey = sortedDates[index];
                      final dayOrders = dateGroups[dateKey]!;
                      final isToday = dateKey == todayIST;
                      final totalRevenue = dayOrders.fold(
                        0.0,
                        (sum, o) => sum + o.vendorEarnings,
                      );

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: isToday,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: [
                                Text(
                                  '📅 ${_formatDateHeader(dateKey)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'TODAY',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${dayOrders.length} order${dayOrders.length > 1 ? 's' : ''} served',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                  ),
                                  Text(
                                    'Revenue: ${CurrencyFormatter.format(totalRevenue)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            children: [
                              const Divider(height: 1, color: AppColors.border),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(12),
                                itemCount: dayOrders.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final order = dayOrders[i];
                                  return _buildHistoryOrderCard(order);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
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

  Widget _buildRoleFilterPill(String role, String label) {
    final isSelected = _roleFilter == role;
    return GestureDetector(
      onTap: () => setState(() => _roleFilter = role),
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

  Widget _buildHistoryOrderCard(OrderModel order) {
    final displayOrderCode = order.id.length >= 8
        ? order.id.substring(0, 8).toUpperCase()
        : order.id.toUpperCase();
    final role = order.customer?.role.toUpperCase() ?? 'STUDENT';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.displayOrderNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '#ORD-$displayOrderCode',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Text(
                CurrencyFormatter.format(order.vendorEarnings),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (order.customer?.name != null)
            Text(
              '👤 ${order.customer!.name} (${order.customer!.email})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 6),
          Column(
            children: order.items.map((i) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${i.quantity}× ${i.itemName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.secondary),
                  ),
                  Text(
                    CurrencyFormatter.format(i.price * i.quantity),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '✓ Completed ${order.completedAt != null ? DateFormatter.formatDateTime(order.completedAt) : ''}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
              ),
              const Text(
                '💳 PAID',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
