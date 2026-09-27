import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/menu_item_model.dart';
import '../../../providers/vendor_provider.dart';
import '../../../widgets/common/async_value_widget.dart';

class VendorMenuManagerScreen extends ConsumerStatefulWidget {
  const VendorMenuManagerScreen({super.key});

  @override
  ConsumerState<VendorMenuManagerScreen> createState() =>
      _VendorMenuManagerScreenState();
}

class _VendorMenuManagerScreenState
    extends ConsumerState<VendorMenuManagerScreen> {

  void _openDishModal({MenuItemModel? existingItem, required String vendorId}) {
    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existingItem != null ? existingItem.price.toString() : '');
    final catCtrl =
        TextEditingController(text: existingItem?.category ?? 'Main Course');
    final descCtrl =
        TextEditingController(text: existingItem?.description ?? '');
    final imgCtrl = TextEditingController(text: existingItem?.image ?? '');
    bool isAvailable = existingItem?.isAvailable ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? '✏️ Edit Menu Item' : '➕ Add New Menu Item',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dish Name *',
                        hintText: 'e.g. Chicken Biryani',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Price
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price (₹) *',
                        hintText: 'e.g. 120.00',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category
                    TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g. Main Course, Snacks, Beverages',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Freshly prepared campus specialty...',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Image URL
                    TextField(
                      controller: imgCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                        hintText: 'https://...',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Availability switch
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('In Stock / Available', style: TextStyle(fontWeight: FontWeight.w600)),
                        value: isAvailable,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setModalState(() => isAvailable = val),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim());

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a dish name')),
                            );
                            return;
                          }
                          if (price == null || price <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid price')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final vendorRepo = ref.read(vendorRepositoryProvider);

                          try {
                            if (isEditing) {
                              await vendorRepo.updateMenuItem(
                                existingItem.id,
                                name: name,
                                price: price,
                                category: catCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                image: imgCtrl.text.trim(),
                                isAvailable: isAvailable,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Dish updated successfully!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } else {
                              await vendorRepo.createMenuItem(
                                name: name,
                                price: price,
                                category: catCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                image: imgCtrl.text.trim(),
                                isAvailable: isAvailable,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('New dish added to menu!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            }
                            ref.invalidate(vendorMenuProvider(vendorId));
                          } catch (err) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${err.toString().replaceAll("Exception: ", "")}'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          isEditing ? 'Save Changes' : 'Add Dish to Menu',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDelete(MenuItemModel item, String vendorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Dish?'),
        content: Text('Are you sure you want to remove "${item.name}" from your canteen menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final vendorRepo = ref.read(vendorRepositoryProvider);
      await vendorRepo.deleteMenuItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.name}" removed from menu'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      ref.invalidate(vendorMenuProvider(vendorId));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${err.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleToggleAvailability(MenuItemModel item, String vendorId) async {
    final newStatus = !item.isAvailable;
    try {
      final vendorRepo = ref.read(vendorRepositoryProvider);
      await vendorRepo.toggleItemAvailability(item.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? '🟢 Marked In Stock' : '🔴 Marked Sold Out'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      ref.invalidate(vendorMenuProvider(vendorId));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${err.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myVendorStoreProvider);

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
              const Text('Menu Manager', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Menu Manager'),
        ),
      ),
      floatingActionButton: storeAsync.value != null
          ? FloatingActionButton.extended(
              onPressed: () => _openDishModal(vendorId: storeAsync.value!.id),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Dish', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: AsyncValueWidget(
        value: storeAsync,
        onRetry: () => ref.invalidate(myVendorStoreProvider),
        data: (store) {
          if (store == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No vendor stall associated with this account.'),
              ),
            );
          }

          final menuAsync = ref.watch(vendorMenuProvider(store.id));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(vendorMenuProvider(store.id));
              ref.invalidate(myVendorStoreProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: AsyncValueWidget<List<MenuItemModel>>(
                value: menuAsync,
                onRetry: () => ref.invalidate(vendorMenuProvider(store.id)),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60.0),
                        child: Column(
                          children: [
                            const Text('🍽️', style: TextStyle(fontSize: 60)),
                            const SizedBox(height: 16),
                            const Text(
                              'No Dishes on Your Menu Yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add your canteen dishes with prices and photos so students can place orders.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _openDishModal(vendorId: store.id),
                              icon: const Icon(Icons.add),
                              label: const Text('+ Add First Dish'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isAvail = item.isAvailable;
                      const defaultImg =
                          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500';
                      final imgUrl = (item.image != null && item.image!.trim().isNotEmpty)
                          ? item.image!.trim()
                          : defaultImg;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      width: 70,
                                      height: 70,
                                      color: const Color(0xFFF1F5F9),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 70,
                                      height: 70,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(Icons.fastfood, color: AppColors.textMuted),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
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
                                            CurrencyFormatter.format(item.price),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      if (item.description != null && item.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Stock Toggle Button
                                ElevatedButton.icon(
                                  onPressed: () => _handleToggleAvailability(item, store.id),
                                  icon: Text(isAvail ? '🟢' : '🔴', style: const TextStyle(fontSize: 11)),
                                  label: Text(
                                    isAvail ? 'In Stock' : 'Sold Out',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isAvail ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAvail ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                    elevation: 0,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _openDishModal(
                                        existingItem: item,
                                        vendorId: store.id,
                                      ),
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                      tooltip: 'Delete Dish',
                                      onPressed: () => _handleDelete(item, store.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
