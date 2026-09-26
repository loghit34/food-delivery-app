import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/vendor_repository.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import 'auth_provider.dart';

final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return VendorRepository(supabase);
});

/// Fetches list of active campus canteens
final activeVendorsProvider = FutureProvider<List<VendorModel>>((ref) async {
  final repo = ref.watch(vendorRepositoryProvider);
  return await repo.getActiveVendors();
});

/// Fetches menu items for a specific canteen
final vendorMenuProvider =
    FutureProvider.family<List<MenuItemModel>, String>((ref, vendorId) async {
  final repo = ref.watch(vendorRepositoryProvider);
  return await repo.getMenuItems(vendorId);
});

/// Fetches vendor store for logged-in vendor user
final myVendorStoreProvider = FutureProvider<VendorModel?>((ref) async {
  final repo = ref.watch(vendorRepositoryProvider);
  return await repo.getMyVendorStore();
});
