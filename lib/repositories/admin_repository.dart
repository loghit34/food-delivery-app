import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/network/api_client.dart';
import '../models/profile_model.dart';
import '../models/vendor_model.dart';
import '../models/order_model.dart';

class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository(this._supabase);

  /// Fetch all registered campus users (Admin only)
  Future<List<ProfileModel>> getAllUsers() async {
    try {
      final res = await ApiClient.get('/auth/users');
      if (res is List) {
        return res
            .map((u) => ProfileModel.fromJson(u as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback direct query
    final response = await _supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((u) => ProfileModel.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  /// Fetch all vendors (both active and inactive)
  Future<List<VendorModel>> getAllVendors() async {
    try {
      final res = await ApiClient.get('/vendors/all');
      if (res is List) {
        return res
            .map((v) => VendorModel.fromJson(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    final response = await _supabase
        .from('vendors')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((v) => VendorModel.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// Toggle vendor active status
  Future<void> toggleVendorStatus(String vendorId, bool isActive) async {
    try {
      await ApiClient.patch(
        '/vendors/$vendorId/status',
        body: {'is_active': isActive},
      );
      return;
    } catch (_) {}

    await _supabase
        .from('vendors')
        .update({'is_active': isActive})
        .eq('id', vendorId);
  }

  /// Create a vendor account and store record
  Future<Map<String, dynamic>> createVendorAccount({
    required String name,
    required String email,
    required String password,
    required String vendorName,
    String? location,
    String? description,
  }) async {
    final payload = {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'vendor_name': vendorName.trim(),
      'location': (location?.trim().isNotEmpty == true)
          ? location!.trim()
          : 'Campus Food Court',
      'description': (description?.trim().isNotEmpty == true)
          ? description!.trim()
          : 'Campus Food Outlet',
    };

    final res = await ApiClient.post('/auth/create-vendor', body: payload);
    if (res is Map<String, dynamic>) {
      return res;
    }
    return {'success': true};
  }

  /// Fetch all global campus orders
  Future<List<OrderModel>> getAllOrders() async {
    try {
      final res = await ApiClient.get('/orders/all');
      if (res is List) {
        return res
            .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback: direct Supabase query
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
          profiles (
            name,
            email,
            role
          ),
          vendors (
            vendor_name,
            location
          ),
          order_items (
            id,
            item_name,
            price,
            quantity
          )
        ''')
        .order('created_at', ascending: false);

    return (response as List)
        .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
        .toList();
  }
}
