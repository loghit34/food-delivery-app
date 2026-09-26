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
    try {
      await ApiClient.put('/menu/$itemId', body: {'is_available': isAvailable});
      return;
    } catch (_) {}

    await _supabase
        .from('menu_items')
        .update({'is_available': isAvailable})
        .eq('id', itemId);
  }

  /// Create a new menu item for the vendor
  Future<MenuItemModel> createMenuItem({
    required String name,
    required double price,
    String? category,
    String? description,
    String? image,
    bool isAvailable = true,
  }) async {
    final payload = {
      'name': name.trim(),
      'price': price,
      'category': category?.trim() ?? 'Main Course',
      'description': description?.trim() ?? '',
      'image': image?.trim() ?? '',
      'is_available': isAvailable,
    };

    try {
      final res = await ApiClient.post('/menu', body: payload);
      if (res is Map<String, dynamic>) {
        return MenuItemModel.fromJson(res);
      }
    } catch (_) {}

    // Fallback: direct Supabase insert if vendor store is known
    final store = await getMyVendorStore();
    if (store == null) throw Exception('No vendor stall linked to this account.');

    final response = await _supabase
        .from('menu_items')
        .insert({
          'vendor_id': store.id,
          'name': name.trim(),
          'price': price,
          'category': category?.trim() ?? 'Main Course',
          'description': description?.trim() ?? '',
          'image': image?.trim() ?? '',
          'is_available': isAvailable,
        })
        .select()
        .single();

    return MenuItemModel.fromJson(response);
  }

  /// Update an existing menu item
  Future<void> updateMenuItem(
    String itemId, {
    String? name,
    double? price,
    String? category,
    String? description,
    String? image,
    bool? isAvailable,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name.trim();
    if (price != null) updates['price'] = price;
    if (category != null) updates['category'] = category.trim();
    if (description != null) updates['description'] = description.trim();
    if (image != null) updates['image'] = image.trim();
    if (isAvailable != null) updates['is_available'] = isAvailable;

    try {
      await ApiClient.put('/menu/$itemId', body: updates);
      return;
    } catch (_) {}

    await _supabase.from('menu_items').update(updates).eq('id', itemId);
  }

  /// Delete a menu item
  Future<void> deleteMenuItem(String itemId) async {
    try {
      await ApiClient.delete('/menu/$itemId');
      return;
    } catch (_) {}

    await _supabase.from('menu_items').delete().eq('id', itemId);
  }

  /// Fetch vendor analytics
  Future<Map<String, dynamic>> getVendorAnalytics() async {
    try {
      final res = await ApiClient.get('/vendors/analytics/me');
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {}
    return {
      'todayOrders': 0,
      'todaySales': 0,
      'totalOrders': 0,
      'totalSales': 0,
    };
  }
}
