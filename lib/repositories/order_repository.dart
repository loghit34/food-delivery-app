import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../core/network/api_client.dart';

class OrderRepository {
  final SupabaseClient _supabase;

  OrderRepository(this._supabase);

  /// Fetch customer orders (Student / Faculty)
  Future<List<OrderModel>> getMyOrders() async {
    try {
      final data = await ApiClient.get('/orders/my-orders');
      if (data is List) {
        return data
            .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback direct Supabase query (RLS ensures user sees only own orders)
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('orders')
        .select('''
          id,
          user_id,
          vendor_id,
          item_total,
          convenience_fee,
          total_amount,
          payment_id,
          status,
          order_date,
          daily_order_number,
          completed_at,
          created_at,
          vendors (
            vendor_name,
            location
          ),
          order_items (
            id,
            menu_item_id,
            item_name,
            price,
            quantity
          )
        ''')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Mark order as received by customer (Atomic transition: PENDING -> COMPLETED)
  Future<void> markOrderReceived(String orderId) async {
    await ApiClient.patch('/orders/$orderId/receive');
  }

  /// Fetch vendor incoming orders (for Vendor Dashboard)
  Future<List<OrderModel>> getVendorOrders() async {
    final data = await ApiClient.get('/orders/vendor-orders');
    if (data is List) {
      return data
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Vendor Realtime Stream for live kitchen tickets
  Stream<List<Map<String, dynamic>>> streamOrdersForVendor(String vendorId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
  }
}
