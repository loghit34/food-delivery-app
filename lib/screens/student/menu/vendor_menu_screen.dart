import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/menu_item_model.dart';
import '../../../models/vendor_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/vendor_provider.dart';
import '../../../widgets/common/async_value_widget.dart';
import '../../../widgets/student/food_card.dart';

class VendorMenuScreen extends ConsumerStatefulWidget {
  final String vendorId;

  const VendorMenuScreen({super.key, required this.vendorId});

  @override
  ConsumerState<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends ConsumerState<VendorMenuScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleAddItem(MenuItemModel item, VendorModel vendor) {
    final cartNotifier = ref.read(cartProvider.notifier);
    final success = cartNotifier.addItem(item, vendor);

    if (!success) {
      final currentVendorName = ref.read(cartProvider).vendor?.vendorName ?? 'another canteen';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace Cart Items?'),
          content: Text(
            'Your cart already contains items from "$currentVendorName". '
            'Would you like to discard them and start an order with "${vendor.vendorName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                cartNotifier.replaceCartWithItem(item, vendor);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ${item.name} to cart!'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Replace Cart', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${item.name} to cart!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorAsync = ref.watch(vendorByIdProvider(widget.vendorId));
    final menuAsync = ref.watch(vendorMenuProvider(widget.vendorId));
    final cartState = ref.watch(cartProvider);

    final isCurrentVendorCart =
        cartState.vendor?.id == widget.vendorId && cartState.items.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: vendorAsync.when(
          data: (vendor) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vendor.vendorName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                '📍 ${vendor.location ?? 'Campus Food Court'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          loading: () => const Text('Loading Canteen...'),
          error: (_, __) => const Text('Canteen Menu'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(vendorMenuProvider(widget.vendorId));
              ref.invalidate(vendorByIdProvider(widget.vendorId));
            },
          ),
        ],
      ),
      bottomNavigationBar: isCurrentVendorCart ? _buildFloatingCartBar(cartState) : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vendorMenuProvider(widget.vendorId));
          ref.invalidate(vendorByIdProvider(widget.vendorId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search canteen dishes...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Menu Items List & Dynamic Categories
              AsyncValueWidget<List<MenuItemModel>>(
                value: menuAsync,
                onRetry: () => ref.invalidate(vendorMenuProvider(widget.vendorId)),
                data: (allItems) {
                  // Extract unique categories
                  final categories = {'ALL'};
                  for (final item in allItems) {
                    if (item.category.trim().isNotEmpty) {
                      categories.add(item.category.trim());
                    }
                  }

                  // Filter items by category & search query
                  final filtered = allItems.where((item) {
                    if (_selectedCategory != 'ALL' &&
                        item.category.toUpperCase() != _selectedCategory.toUpperCase()) {
                      return false;
                    }
                    if (_searchQuery.isNotEmpty) {
                      final matchName = item.name.toLowerCase().contains(_searchQuery);
                      final matchDesc = item.description?.toLowerCase().contains(_searchQuery) ?? false;
                      final matchCat = item.category.toLowerCase().contains(_searchQuery);
                      return matchName || matchDesc || matchCat;
                    }
                    return true;
                  }).toList();

                  final vendor = vendorAsync.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Chips
                      if (categories.length > 1)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categories.map((cat) {
                              final isSelected = _selectedCategory.toUpperCase() == cat.toUpperCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(
                                    cat == 'ALL' ? '🍽️ All' : cat,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.secondary,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                  ),
                                  onSelected: (_) => setState(() => _selectedCategory = cat),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Count Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Menu Dishes (${filtered.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (filtered.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Column(
                              children: [
                                const Text('🔍', style: TextStyle(fontSize: 40)),
                                const SizedBox(height: 10),
                                const Text(
                                  'No dishes found',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Try adjusting your search or category filter.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedCategory = 'ALL';
                                    });
                                  },
                                  child: const Text('View All Dishes'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final cartItem = cartState.items
                                .where((ci) => ci.item.id == item.id)
                                .firstOrNull;
                            final quantity = cartItem?.quantity ?? 0;

                            return FoodCard(
                              item: item,
                              cartQuantity: quantity,
                              onAdd: () {
                                if (vendor != null) {
                                  _handleAddItem(item, vendor);
                                }
                              },
                              onIncrement: () {
                                ref.read(cartProvider.notifier).updateQuantity(item.id, 1);
                              },
                              onDecrement: () {
                                ref.read(cartProvider.notifier).updateQuantity(item.id, -1);
                              },
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCartBar(CartState cart) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cart.totalItemCount} item${cart.totalItemCount > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                Text(
                  CurrencyFormatter.format(cart.subtotal),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => context.push('/cart'),
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text(
                'View Cart →',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
