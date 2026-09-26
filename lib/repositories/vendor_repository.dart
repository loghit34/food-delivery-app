import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import '../core/network/api_client.dart';

class VendorRepository {
  final SupabaseClient _supabase;

  VendorRepository(this._supabase);

  /// Fetch all active campus canteens
  Future<List<VendorModel>> getActiveVendors() async {
    final response = await _supabase
        .from('vendors')
        .select()
        .eq('is_active', true)
        .order('vendor_name', ascending: true);

    return (response as List)
        .map((json) => VendorModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get vendor details by ID
  Future<VendorModel> getVendorById(String vendorId) async {
    final response = await _supabase
        .from('vendors')
        .select()
        .eq('id', vendorId)
        .single();

    return VendorModel.fromJson(response);
  }

  /// Fetch menu items for a specific canteen
  Future<List<MenuItemModel>> getMenuItems(String vendorId) async {
    final response = await _supabase
        .from('menu_items')
        .select()
        .eq('vendor_id', vendorId)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => MenuItemModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get vendor shop associated with the current vendor account
  Future<VendorModel?> getMyVendorStore() async {
    try {
      final data = await ApiClient.get('/vendors/shop/me');
      if (data != null && data is Map<String, dynamic>) {
        return VendorModel.fromJson(data);
      }
    } catch (_) {}

    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('vendors')
        .select()
        .eq('owner_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return VendorModel.fromJson(response);
  }

  /// Toggle item stock availability (Vendor action)
  Future<void> toggleItemAvailability(String itemId, bool isAvailable) async {
    await _supabase
        .from('menu_items')
        .update({'is_available': isAvailable})
        .eq('id', itemId);
  }
}
