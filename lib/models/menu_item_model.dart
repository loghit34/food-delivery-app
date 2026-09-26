class MenuItemModel {
  final String id;
  final String vendorId;
  final String name;
  final String? description;
  final double price;
  final String? image;
  final bool isAvailable;
  final String category;
  final DateTime? createdAt;

  MenuItemModel({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    required this.price,
    this.image,
    this.isAvailable = true,
    this.category = 'Main Course',
    this.createdAt,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'] as String,
      vendorId: (json['vendor_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      description: json['description'] as String?,
      price: (json['price'] != null)
          ? double.tryParse(json['price'].toString()) ?? 0.0
          : 0.0,
      image: json['image'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      category: (json['category'] ?? 'Main Course') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'name': name,
      'description': description,
      'price': price,
      'image': image,
      'is_available': isAvailable,
      'category': category,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
