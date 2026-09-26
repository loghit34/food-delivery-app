import 'menu_item_model.dart';

class CartItemModel {
  final MenuItemModel item;
  final int quantity;

  CartItemModel({
    required this.item,
    required this.quantity,
  });

  double get totalPrice => item.price * quantity;

  CartItemModel copyWith({
    MenuItemModel? item,
    int? quantity,
  }) {
    return CartItemModel(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': item.id,
      'name': item.name,
      'price': item.price,
      'quantity': quantity,
    };
  }
}
