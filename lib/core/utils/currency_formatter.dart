import 'package:intl/intl.dart';

/// INR Currency Formatter (₹)
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String format(num? amount) {
    if (amount == null) return '₹0.00';
    return _formatter.format(amount);
  }

  static String formatNoDecimals(num? amount) {
    if (amount == null) return '₹0';
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}
