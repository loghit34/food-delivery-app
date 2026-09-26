import '../core/network/api_client.dart';
import '../models/cart_item_model.dart';

class PaymentOrderInitResponse {
  final String keyId;
  final String orderId;
  final int amount; // in paise
  final String currency;
  final double verifiedTotal;
  final double itemTotal;
  final double convenienceFee;

  PaymentOrderInitResponse({
    required this.keyId,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.verifiedTotal,
    required this.itemTotal,
    required this.convenienceFee,
  });

  factory PaymentOrderInitResponse.fromJson(Map<String, dynamic> json) {
    return PaymentOrderInitResponse(
      keyId: (json['keyId'] ?? '') as String,
      orderId: (json['orderId'] ?? '') as String,
      amount: (json['amount'] is int)
          ? json['amount'] as int
          : int.tryParse(json['amount'].toString()) ?? 0,
      currency: (json['currency'] ?? 'INR') as String,
      verifiedTotal: (json['verifiedTotal'] != null)
          ? double.tryParse(json['verifiedTotal'].toString()) ?? 0.0
          : 0.0,
      itemTotal: (json['itemTotal'] != null)
          ? double.tryParse(json['itemTotal'].toString()) ?? 0.0
          : 0.0,
      convenienceFee: (json['convenienceFee'] != null)
          ? double.tryParse(json['convenienceFee'].toString()) ?? 4.0
          : 4.0,
    );
  }
}

class PaymentVerificationResult {
  final String orderId;
  final int? dailyOrderNumber;
  final String status;
  final double totalAmount;

  PaymentVerificationResult({
    required this.orderId,
    this.dailyOrderNumber,
    required this.status,
    required this.totalAmount,
  });

  factory PaymentVerificationResult.fromJson(Map<String, dynamic> json) {
    return PaymentVerificationResult(
      orderId: (json['orderId'] ?? '') as String,
      dailyOrderNumber: json['dailyOrderNumber'] != null
          ? int.tryParse(json['dailyOrderNumber'].toString())
          : null,
      status: (json['status'] ?? 'PENDING') as String,
      totalAmount: (json['totalAmount'] != null)
          ? double.tryParse(json['totalAmount'].toString()) ?? 0.0
          : 0.0,
    );
  }
}

class PaymentRepository {
  /// Step 1: Request official Razorpay order from backend
  Future<PaymentOrderInitResponse> createOrder({
    required String vendorId,
    required List<CartItemModel> items,
  }) async {
    final response = await ApiClient.post(
      '/payment/create-order',
      body: {
        'vendorId': vendorId,
        'items': items.map((i) => i.toJson()).toList(),
      },
    );

    return PaymentOrderInitResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Step 2: Verify Razorpay signature server-side and create DB order
  Future<PaymentVerificationResult> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await ApiClient.post(
      '/payment/verify',
      body: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      },
    );

    return PaymentVerificationResult.fromJson(response as Map<String, dynamic>);
  }
}
