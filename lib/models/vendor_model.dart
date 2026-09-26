class VendorModel {
  final String id;
  final String? ownerId;
  final String vendorName;
  final String? description;
  final String? location;
  final String? image;
  final bool isActive;
  final DateTime? createdAt;

  VendorModel({
    required this.id,
    this.ownerId,
    required this.vendorName,
    this.description,
    this.location,
    this.image,
    this.isActive = true,
    this.createdAt,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String?,
      vendorName: (json['vendor_name'] ?? 'Canteen') as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      image: json['image'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'vendor_name': vendorName,
      'description': description,
      'location': location,
      'image': image,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
