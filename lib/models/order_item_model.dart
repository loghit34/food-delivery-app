class OrderItemModel {
  final String id;
  final String? menuItemId;
  final String itemName;
  final double price;
  final int quantity;

  OrderItemModel({
    required this.id,
    this.menuItemId,
    required this.itemName,
    required this.price,
    required this.quantity,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: (json['id'] ?? '').toString(),
      menuItemId: json['menu_item_id']?.toString(),
      itemName: (json['item_name'] ?? '').toString(),
      price: (json['price'] != null)
          ? double.tryParse(json['price'].toString()) ?? 0.0
          : 0.0,
      quantity: (json['quantity'] != null)
          ? int.tryParse(json['quantity'].toString()) ?? 1
          : 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'item_name': itemName,
      'price': price,
      'quantity': quantity,
    };
  }
}
