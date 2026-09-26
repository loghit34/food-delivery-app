import 'package:flutter/material.dart';

/// UEM-EATS Centralized Brand and UI Color System
/// Visually consistent with the official UEM EATS web design system
class AppColors {
  AppColors._();

  // Primary Brand Colors (Orange #F97316)
  static const Color primary = Color(0xFFF97316); // UEM Orange
  static const Color primaryDark = Color(0xFFEA580C); // Orange Dark (700)
  static const Color primaryLight = Color(0xFFFFEDD5); // Light Primary (Orange 100)

  // Secondary & Neutral Colors
  static const Color secondary = Color(0xFF0F172A); // Slate 900 (Dark Text)
  static const Color secondaryHover = Color(0xFF1E293B); // Slate 800

  // Background & Surface
  static const Color background = Color(0xFFF8FAFC); // Slate 50 Background
  static const Color card = Color(0xFFFFFFFF); // Card White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0); // Slate 200 Border
  static const Color borderFocus = Color(0xFFF97316);

  // Typography Colors
  static const Color textDark = Color(0xFF0F172A); // Dark Text (#0F172A)
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B); // Secondary Text (#64748B)
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8); // Slate 400

  // Status: Success (Green #16A34A)
  // Used for: Open canteen, Payment successful, Paid, Success messages
  static const Color success = Color(0xFF16A34A); // Success Green
  static const Color successDark = Color(0xFF15803D); // Green 700
  static const Color successLight = Color(0xFFDCFCE7); // Green 100
  static const Color successBg = Color(0xFFDCFCE7);

  // Status: Warning / Pending (Amber #F59E0B)
  // Used for: Pending, Waiting, Processing
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningDark = Color(0xFFD97706); // Amber 600
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color accent = warning;

  // Status: Error / Danger (Red #DC2626)
  // Reserved ONLY for: Payment failed, Errors, Delete, Cancel/destructive actions, Validation errors
  static const Color danger = Color(0xFFDC2626); // Danger Red
  static const Color dangerDark = Color(0xFFB91C1C); // Red 700
  static const Color dangerLight = Color(0xFFFEE2E2); // Red 100
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color error = danger;
}
