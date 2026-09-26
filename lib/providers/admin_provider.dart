import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/admin_repository.dart';
import '../models/profile_model.dart';
import '../models/vendor_model.dart';
import '../models/order_model.dart';
import 'auth_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AdminRepository(supabase);
});

final adminUsersProvider = FutureProvider<List<ProfileModel>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return await repo.getAllUsers();
});

final adminVendorsProvider = FutureProvider<List<VendorModel>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return await repo.getAllVendors();
});

final adminOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return await repo.getAllOrders();
});
