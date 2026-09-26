import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../repositories/payment_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late Razorpay _razorpay;
  bool _isProcessing = false;
  bool _isVerifying = false;
  bool _paymentCompleted = false;
  String? _statusText;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    debugPrint('💳 [Razorpay Init] Initializing Razorpay instance and event listeners...');
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    debugPrint('💳 [Razorpay Init] Razorpay instance initialized successfully.');
  }

  @override
  void dispose() {
    debugPrint('💳 [Razorpay Dispose] Clearing Razorpay event listeners...');
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('====================================================');
    debugPrint('✅ [Razorpay Event] EVENT_PAYMENT_SUCCESS received from Razorpay SDK');
    debugPrint('   Payment ID: ${response.paymentId}');
    debugPrint('   Order ID:   ${response.orderId}');
    debugPrint('   Signature:  ${response.signature}');
    debugPrint('====================================================');

    // Prevent duplicate callback executions
    if (_isVerifying || _paymentCompleted) {
      debugPrint('⚠️ [Razorpay Event] Ignoring duplicate payment success event callback.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _isVerifying = true;
      _statusText = '🔒 Verifying payment signature with server...';
    });

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final razorpayOrderId = (response.orderId != null && response.orderId!.isNotEmpty)
          ? response.orderId!
          : (_currentOrderId ?? '');

      if (razorpayOrderId.isEmpty) {
        throw Exception('Razorpay Order ID missing during verification.');
      }
      if (response.paymentId == null || response.paymentId!.isEmpty) {
        throw Exception('Razorpay Payment ID missing during verification.');
      }
      if (response.signature == null || response.signature!.isEmpty) {
        throw Exception('Razorpay Signature missing from checkout response.');
      }

      debugPrint('💳 [Razorpay Verify] Sending verification payload to backend...');
      final verifyRes = await paymentRepo.verifyPayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );

      debugPrint('====================================================');
      debugPrint('🎉 [Razorpay Verify] Backend verification SUCCESS:');
      debugPrint('   Order ID:      ${verifyRes.orderId}');
      debugPrint('   Daily #:       #${verifyRes.dailyOrderNumber}');
      debugPrint('   Status:        ${verifyRes.status}');
      debugPrint('   Total Amount:  ₹${verifyRes.totalAmount}');
      debugPrint('====================================================');

      // Set completion flag BEFORE clearing cart so build() does NOT redirect to /cart
      _paymentCompleted = true;
      _isVerifying = false;
      _isProcessing = false;

      // Clear the cart only after successful payment and backend verification
      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        final dailyNum = verifyRes.dailyOrderNumber?.toString() ?? '1';
        final status = verifyRes.status.isNotEmpty ? verifyRes.status : 'PENDING';
        context.go(
          '/payment-success?orderId=${Uri.encodeComponent(verifyRes.orderId)}&dailyNum=${Uri.encodeComponent(dailyNum)}&status=${Uri.encodeComponent(status)}',
        );
      }
    } catch (err, stack) {
      debugPrint('❌ [Razorpay Verify] Server verification failed: $err\n$stack');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isVerifying = false;
          _statusText = null;
        });
        _showErrorDialog(
          title: 'Payment Verification Failed',
          message: 'Payment was completed, but backend verification failed:\n${err.toString().replaceAll("Exception: ", "")}\n\nYour cart has been preserved.',
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('====================================================');
    debugPrint('🚨 [Razorpay Event] EVENT_PAYMENT_ERROR received');
    debugPrint('   Code:    ${response.code}');
    debugPrint('   Message: ${response.message}');
    debugPrint('   Error:   ${response.error}');
    debugPrint('====================================================');

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _isVerifying = false;
      _statusText = null;
    });

    String displayMessage = response.message ?? 'Payment was cancelled or failed.';
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      displayMessage = 'Payment was cancelled. You can try again whenever you are ready.';
    } else if (response.code == Razorpay.NETWORK_ERROR) {
      displayMessage = 'Network connection issue during payment. Please check your internet connection and try again.';
    } else if (response.code == Razorpay.TLS_ERROR) {
      displayMessage = 'Security/TLS protocol error. Please verify device date and network settings.';
    }

    _showErrorDialog(
      title: 'Payment Incomplete',
      message: '$displayMessage\n(Code: ${response.code})',
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('====================================================');
    debugPrint('💳 [Razorpay Event] EVENT_EXTERNAL_WALLET: ${response.walletName}');
    debugPrint('====================================================');

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _isVerifying = false;
      _statusText = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirecting to ${response.walletName}...'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  void _showErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePayment() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || cart.vendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty.'),
          backgroundColor: AppColors.danger,
        ),
      );
      context.pop();
      return;
    }

    final profileAsync = ref.read(userProfileProvider);
    final user = profileAsync.value;

    debugPrint('====================================================');
    debugPrint('🚀 [Razorpay Flow] Step 1: User tapped Pay button');
    debugPrint('   Vendor: ${cart.vendor?.vendorName} (${cart.vendor?.id})');
    debugPrint('   Items count: ${cart.items.length}');
    debugPrint('   Item Total: ₹${cart.subtotal}, Grand Total: ₹${cart.grandTotal}');
    debugPrint('====================================================');

    setState(() {
      _isProcessing = true;
      _statusText = '⏳ Requesting order from server...';
    });

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);

      // Step 1: Create Razorpay Order on backend
      debugPrint('📡 [Razorpay Flow] Calling POST /payment/create-order on backend...');
      final initRes = await paymentRepo.createOrder(
        vendorId: cart.vendor!.id,
        items: cart.items,
      );

      debugPrint('====================================================');
      debugPrint('✅ [Razorpay Flow] Step 2: Backend order response received:');
      debugPrint('   Key ID:            ${initRes.keyId}');
      debugPrint('   Razorpay Order ID: ${initRes.orderId}');
      debugPrint('   Amount (paise):    ${initRes.amount}');
      debugPrint('   Currency:          ${initRes.currency}');
      debugPrint('   Verified Total:    ₹${initRes.verifiedTotal}');
      debugPrint('   Convenience Fee:   ₹${initRes.convenienceFee}');
      debugPrint('====================================================');

      if (initRes.orderId.isEmpty) {
        throw Exception('Server returned an empty Razorpay Order ID.');
      }

      if (initRes.amount <= 0) {
        throw Exception('Server returned invalid payable amount: ${initRes.amount}');
      }

      _currentOrderId = initRes.orderId;

      final resolvedKeyId = initRes.keyId.isNotEmpty ? initRes.keyId : AppConfig.razorpayKeyId;

      if (resolvedKeyId.isEmpty) {
        throw Exception('Razorpay Key ID is not configured.');
      }

      setState(() {
        _statusText = '💳 Opening Razorpay Checkout...';
      });

      // Step 2: Construct official Razorpay options
      final options = {
        'key': resolvedKeyId,
        'amount': initRes.amount, // in paise, e.g. 6200 for ₹62
        'name': 'UEM EATS',
        'order_id': initRes.orderId,
        'currency': initRes.currency.isNotEmpty ? initRes.currency : 'INR',
        'description': 'Order Payment - ${cart.vendor?.vendorName ?? "Canteen"}',
        'timeout': 180,
        'prefill': {
          'email': user?.email ?? '',
          'name': user?.name ?? 'Student',
        },
        'theme': {
          'color': '#E53935',
        },
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
      };

      debugPrint('💳 [Razorpay Flow] Step 3: Executing Razorpay.open(options)...');
      debugPrint('   Options map: $options');

      // Step 3: Open Razorpay Checkout Screen
      _razorpay.open(options);
      debugPrint('✅ [Razorpay Flow] Razorpay.open(options) successfully executed.');
    } catch (err, stack) {
      debugPrint('❌ [Razorpay Flow] Error initiating Razorpay checkout: $err\n$stack');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = null;
        });
        _showErrorDialog(
          title: 'Could Not Start Payment',
          message: '${err.toString().replaceAll("Exception: ", "")}\n\nYour cart has been preserved.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final user = profileAsync.value;

    // Only redirect to cart if the user arrived at checkout with an empty cart
    // and is NOT currently processing or completing a payment
    if (cart.isEmpty && !_isProcessing && !_isVerifying && !_paymentCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isProcessing && !_isVerifying && !_paymentCompleted) {
          context.go('/cart');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_paymentCompleted) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Details Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.name ?? 'Student',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Role: ${user?.role ?? 'STUDENT'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Canteen Outlet Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Text('🏪', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Canteen Outlet',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      Text(
                        cart.vendor?.vendorName ?? 'Canteen',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Items in Order Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items in Order',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.item.name} × ${item.quantity}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            CurrencyFormatter.format(item.totalPrice),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Summary Breakdown Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Item Total', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      Text(CurrencyFormatter.format(cart.subtotal), style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Platform Convenience Fee', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      Row(
                        children: [
                          Text(
                            CurrencyFormatter.format(AppConstants.originalConvenienceFee),
                            style: const TextStyle(
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            CurrencyFormatter.format(AppConstants.currentConvenienceFee),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total (Payable Online)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(cart.grandTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status message
            if (_statusText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            // Payment Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isProcessing || _isVerifying) ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: (_isProcessing || _isVerifying)
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '💳 Pay ${CurrencyFormatter.format(cart.grandTotal)} via Razorpay',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
