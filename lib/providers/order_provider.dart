import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/order_repository.dart';
import '../models/order_model.dart';
import 'auth_provider.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return OrderRepository(supabase);
});

/// Fetches customer orders for the logged-in student or faculty
final customerOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return await repo.getMyOrders();
});

/// Fetches vendor incoming orders
final vendorOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return await repo.getVendorOrders();
});
