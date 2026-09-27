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
  ProfileModel? get profile => customer;

  String get displayOrderNumber => dailyOrderNumber != null
      ? '#$dailyOrderNumber'
      : (id.isNotEmpty
          ? '#${id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase()}'
          : '#ORD');

  double get calculatedItemTotal {
    if (items.isNotEmpty) {
      final sum = items.fold<double>(
        0.0,
        (acc, item) => acc + (item.price * item.quantity),
      );
      if (sum > 0) return sum;
    }
    return itemTotal;
  }

  /// Total customer payment (food items subtotal + platform/maintenance fee)
  double get customerTotal => totalAmount;

  /// Platform / maintenance fee charged to customer
  double get platformFee => convenienceFee;

  /// Item/order subtotal (pure food cost)
  double get orderSubtotal {
    if (itemTotal > 0) {
      return itemTotal;
    }
    final calculated = calculatedItemTotal;
    if (calculated > 0) {
      return calculated;
    }
    if (totalAmount >= convenienceFee && convenienceFee > 0) {
      return totalAmount - convenienceFee;
    }
    return totalAmount;
  }

  /// Vendor payable amount (strictly the item/order subtotal, excluding platform fee)
  double get vendorAmount => orderSubtotal;

  /// Alias for backwards compatibility
  double get vendorEarnings => vendorAmount;

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

    final parsedItemTotal = (json['item_total'] != null ||
            json['itemTotal'] != null ||
            json['subtotal'] != null ||
            json['vendor_amount'] != null)
        ? double.tryParse((json['item_total'] ??
                json['itemTotal'] ??
                json['subtotal'] ??
                json['vendor_amount'])
            .toString()) ??
            0.0
        : 0.0;

    final parsedFee = (json['convenience_fee'] != null ||
            json['convenienceFee'] != null ||
            json['platform_fee'] != null ||
            json['maintenance_fee'] != null)
        ? double.tryParse((json['convenience_fee'] ??
                json['convenienceFee'] ??
                json['platform_fee'] ??
                json['maintenance_fee'])
            .toString()) ??
            4.0
        : 4.0;

    final parsedTotal = (json['total_amount'] != null ||
            json['totalAmount'] != null ||
            json['customer_total'] != null)
        ? double.tryParse((json['total_amount'] ??
                json['totalAmount'] ??
                json['customer_total'])
            .toString()) ??
            0.0
        : 0.0;

    final effectiveItemTotal = (parsedItemTotal > 0.0)
        ? parsedItemTotal
        : (items.isNotEmpty
            ? items.fold<double>(0.0, (sum, i) => sum + (i.price * i.quantity))
            : (parsedTotal >= parsedFee && parsedFee > 0.0
                ? parsedTotal - parsedFee
                : parsedTotal));

    return OrderModel(
      id: (json['id'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      vendorId: (json['vendor_id'] ?? '').toString(),
      itemTotal: effectiveItemTotal,
      convenienceFee: parsedFee,
      totalAmount: parsedTotal,
      paymentId: json['payment_id']?.toString(),
      status: (json['status'] ?? 'PENDING').toString(),
      orderDate: json['order_date']?.toString(),
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
