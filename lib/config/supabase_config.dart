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

// TODO: 
// 1. Go to https://supabase.com and create a new project
// 2. Go to Project Settings > API
// 3. Copy the Project URL and paste it as supabaseUrl
// 4. Copy the anon/public key and paste it as supabaseAnonKey
// 5. Set up authentication in Supabase dashboard:
//    - Go to Authentication > Settings
//    - Enable Email provider
//    - Configure email templates if needed
// 6. Create user roles table if needed:
//    CREATE TABLE user_roles (
//      id UUID REFERENCES auth.users ON DELETE CASCADE,
//      role TEXT DEFAULT 'user',
//      created_at TIMESTAMP DEFAULT NOW(),
//      PRIMARY KEY (id)
//    );