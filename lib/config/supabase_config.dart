import 'package:flutter_dotenv/flutter_dotenv.dart';

// Supabase configuration loaded from environment variables
// Make sure to load dotenv before using these values
class SupabaseConfig {
  // Your Supabase project URL from .env file
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? _throwError('SUPABASE_URL');

  // Your Supabase anon/public key from .env file
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _throwError('SUPABASE_ANON_KEY');

  // Optional: Redirect URL for password reset from .env file
  static String get redirectUrl =>
      dotenv.env['REDIRECT_URL'] ?? 'https://your-app.com/auth/callback';

  // Helper method to throw error if environment variable is missing
  static String _throwError(String key) {
    throw Exception(
      'Environment variable $key is not set. Make sure to load .env file.',
    );
  }
}
