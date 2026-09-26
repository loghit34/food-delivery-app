import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item_model.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../core/constants/app_constants.dart';

class CartState {
  final VendorModel? vendor;
  final List<CartItemModel> items;

  CartState({
    this.vendor,
    this.items = const [],
  });

  bool get isEmpty => items.isEmpty;
  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get convenienceFee =>
      isEmpty ? 0.0 : AppConstants.currentConvenienceFee;

  double get grandTotal => isEmpty ? 0.0 : subtotal + convenienceFee;

  CartState copyWith({
    VendorModel? vendor,
    List<CartItemModel>? items,
    bool clearVendor = false,
  }) {
    return CartState(
      vendor: clearVendor ? null : (vendor ?? this.vendor),
      items: items ?? this.items,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  /// Returns true if added, false if vendor mismatch prevents adding without clearing
  bool addItem(MenuItemModel item, VendorModel vendor) {
    // Single-Vendor Enforcement Rule
    if (state.vendor != null &&
        state.vendor!.id != vendor.id &&
        state.items.isNotEmpty) {
      return false; // Caller must prompt user to clear or replace cart
    }

    final currentItems = List<CartItemModel>.from(state.items);
    final existingIndex = currentItems.indexWhere((i) => i.item.id == item.id);

    if (existingIndex >= 0) {
      final existing = currentItems[existingIndex];
      currentItems[existingIndex] =
          existing.copyWith(quantity: existing.quantity + 1);
    } else {
      currentItems.add(CartItemModel(item: item, quantity: 1));
    }

    state = CartState(vendor: vendor, items: currentItems);
    return true;
  }

  /// Discards previous vendor's items and adds the new item
  void replaceCartWithItem(MenuItemModel item, VendorModel vendor) {
    state = CartState(
      vendor: vendor,
      items: [CartItemModel(item: item, quantity: 1)],
    );
  }

  void updateQuantity(String itemId, int delta) {
    final currentItems = List<CartItemModel>.from(state.items);
    final index = currentItems.indexWhere((i) => i.item.id == itemId);

    if (index >= 0) {
      final newQty = currentItems[index].quantity + delta;
      if (newQty <= 0) {
        currentItems.removeAt(index);
      } else {
        currentItems[index] =
            currentItems[index].copyWith(quantity: newQty);
      }
    }

    if (currentItems.isEmpty) {
      state = CartState();
    } else {
      state = state.copyWith(items: currentItems);
    }
  }

  void removeItem(String itemId) {
    final currentItems =
        state.items.where((i) => i.item.id != itemId).toList();
    if (currentItems.isEmpty) {
      state = CartState();
    } else {
      state = state.copyWith(items: currentItems);
    }
  }

  void clearCart() {
    state = CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
