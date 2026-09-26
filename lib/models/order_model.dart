import 'order_item_model.dart';
import 'vendor_model.dart';
import 'profile_model.dart';

class OrderModel {
  final String id;
  final String? userId;
  final String vendorId;
  final double itemTotal;
  final double convenienceFee;
  final double totalAmount;
  final String? paymentId;
  final String status; // 'PENDING' | 'COMPLETED' | 'PAID'
  final String? orderDate;
  final int? dailyOrderNumber;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final VendorModel? vendor;
  final ProfileModel? customer;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    this.userId,
    required this.vendorId,
    required this.itemTotal,
    this.convenienceFee = 4.00,
    required this.totalAmount,
    this.paymentId,
    required this.status,
    this.orderDate,
    this.dailyOrderNumber,
    this.completedAt,
    this.createdAt,
    this.vendor,
    this.customer,
    this.items = const [],
  });

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isPending => status.toUpperCase() == 'PENDING';

  String get displayOrderNumber => dailyOrderNumber != null
      ? '#$dailyOrderNumber'
      : '#${id.substring(0, 6).toUpperCase()}';

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    VendorModel? vendor;
    if (json['vendors'] is Map<String, dynamic>) {
      vendor = VendorModel.fromJson(json['vendors'] as Map<String, dynamic>);
    } else if (json['vendors'] is List && (json['vendors'] as List).isNotEmpty) {
      final first = (json['vendors'] as List).first;
      if (first is Map<String, dynamic>) {
        vendor = VendorModel.fromJson(first);
      }
    }

    ProfileModel? customer;
    if (json['profiles'] is Map<String, dynamic>) {
      customer = ProfileModel.fromJson(json['profiles'] as Map<String, dynamic>);
    } else if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
      final first = (json['profiles'] as List).first;
      if (first is Map<String, dynamic>) {
        customer = ProfileModel.fromJson(first);
      }
    }

    List<OrderItemModel> items = [];
    if (json['order_items'] is List) {
      items = (json['order_items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((i) => OrderItemModel.fromJson(i))
          .toList();
    }

    return OrderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      vendorId: (json['vendor_id'] ?? '') as String,
      itemTotal: (json['item_total'] != null)
          ? double.tryParse(json['item_total'].toString()) ?? 0.0
          : 0.0,
      convenienceFee: (json['convenience_fee'] != null)
          ? double.tryParse(json['convenience_fee'].toString()) ?? 4.0
          : 4.0,
      totalAmount: (json['total_amount'] != null)
          ? double.tryParse(json['total_amount'].toString()) ?? 0.0
          : 0.0,
      paymentId: json['payment_id'] as String?,
      status: (json['status'] ?? 'PENDING') as String,
      orderDate: json['order_date'] as String?,
      dailyOrderNumber: json['daily_order_number'] != null
          ? int.tryParse(json['daily_order_number'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      vendor: vendor,
      customer: customer,
      items: items,
    );
  }
}
