
/// Secure Application Configuration Manager
/// Loads settings from asset .env file, keeping sensitive config dynamic
class AppConfig {
  AppConfig._();

  static late String supabaseUrl;
  static late String supabaseAnonKey;
  static late String apiBaseUrl;
  static late String razorpayKeyId;

  static Future<void> initialize() async {
    // 1. Check for compile-time environment variables (--dart-define)
    const envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const envSupabaseAnon = String.fromEnvironment('SUPABASE_ANON_KEY');
    const envApiBase = String.fromEnvironment('API_BASE_URL');
    const envRazorpayKey = String.fromEnvironment('RAZORPAY_KEY_ID');

    // 2. Set defaults matching live verified project configuration
    supabaseUrl = envSupabaseUrl.isNotEmpty
        ? envSupabaseUrl
        : 'https://abuopjnbspnusijjtnuj.supabase.co';

    supabaseAnonKey = envSupabaseAnon.isNotEmpty
        ? envSupabaseAnon
        : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFidW9wam5ic3BudXNpamp0bnVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyNzQxNDYsImV4cCI6MjEwNDg1MDE0Nn0.HWQexbBGPlWj5xHeG-Y9du57rtuJvGXYh7sAAKJLEjc';

    apiBaseUrl = envApiBase.isNotEmpty
        ? envApiBase
        : 'https://uem-foodyy.vercel.app/api';

    razorpayKeyId = envRazorpayKey.isNotEmpty
        ? envRazorpayKey
        : 'rzp_test_TfwGbybAuVJhvq';
  }
}
