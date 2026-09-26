import 'package:flutter/services.dart';

/// Secure Application Configuration Manager
/// Loads settings from asset .env file, keeping sensitive config dynamic
class AppConfig {
  AppConfig._();

  static late String supabaseUrl;
  static late String supabaseAnonKey;
  static late String apiBaseUrl;
  static late String razorpayKeyId;

  static Future<void> initialize() async {
    // Defaults matching live verified project configuration
    supabaseUrl = 'https://abuopjnbspnusijjtnuj.supabase.co';
    supabaseAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFidW9wam5ic3BudXNpamp0bnVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyNzQxNDYsImV4cCI6MjEwNDg1MDE0Nn0.HWQexbBGPlWj5xHeG-Y9du57rtuJvGXYh7sAAKJLEjc';
    apiBaseUrl = 'https://uem-foodyy.vercel.app/api';
    razorpayKeyId = '';

    try {
      final envString = await rootBundle.loadString('.env');
      final lines = envString.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final val = parts.sublist(1).join('=').trim();
          if (key == 'SUPABASE_URL' && val.isNotEmpty) supabaseUrl = val;
          if (key == 'SUPABASE_ANON_KEY' && val.isNotEmpty) supabaseAnonKey = val;
          if (key == 'API_BASE_URL' && val.isNotEmpty) apiBaseUrl = val;
          if (key == 'RAZORPAY_KEY_ID' && val.isNotEmpty) razorpayKeyId = val;
        }
      }
    } catch (_) {
      // In production builds if .env asset is absent, falls back to safe static defaults above
    }
  }
}
