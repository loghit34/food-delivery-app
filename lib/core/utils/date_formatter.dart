import 'package:intl/intl.dart';

/// IST (Asia/Kolkata) Date & Time Formatter
class DateFormatter {
  DateFormatter._();

  static String formatDateTime(dynamic date) {
    if (date == null) return '';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      try {
        dt = DateTime.parse(date);
      } catch (_) {
        return date;
      }
    } else {
      return '';
    }

    // Convert to IST offset (UTC+5:30)
    final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('d MMM y, h:mm a').format(ist);
  }

  static String formatDate(dynamic date) {
    if (date == null) return '';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      try {
        dt = DateTime.parse(date);
      } catch (_) {
        return date;
      }
    } else {
      return '';
    }

    final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('d MMM y').format(ist);
  }

  static String formatTimeAgo(dynamic date) {
    if (date == null) return '';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      try {
        dt = DateTime.parse(date);
      } catch (_) {
        return '';
      }
    } else {
      return '';
    }

    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
