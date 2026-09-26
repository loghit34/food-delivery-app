/// Application Constants matching backend rules
class AppConstants {
  AppConstants._();

  static const String appName = 'UEM EATS';
  static const String appTagline = 'Campus Food Ordering Platform';

  // Fee configuration (verified from database and backend rules)
  static const double originalConvenienceFee = 6.00;
  static const double currentConvenienceFee = 4.00;

  // Roles allowed by database constraint: CHECK (role IN ('STUDENT', 'FACULTY', 'VENDOR', 'ADMIN'))
  static const String roleStudent = 'STUDENT';
  static const String roleFaculty = 'FACULTY';
  static const String roleVendor = 'VENDOR';
  static const String roleAdmin = 'ADMIN';

  // Order Status Lifecycle
  static const String statusPending = 'PENDING';
  static const String statusCompleted = 'COMPLETED';
  static const String statusPaid = 'PAID';
}
