// Example configuration file
// Copy this to supabase_config.dart and replace with your actual credentials

class SupabaseConfig {
  // Replace with your actual Supabase project URL
  // Example: 'https://xyzcompany.supabase.co'
  static const String supabaseUrl = 'https://hdjsoucuqegosvasovla.supabase.co';

  // Replace with your actual Supabase anon/public key
  // This is safe to expose in client-side code
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkanNvdWN1cWVnb3N2YXNvdmxhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA4ODc5NjAsImV4cCI6MjA3NjQ2Mzk2MH0.yKSiX5jD5oumdhzmnplkNS3ghzj_4Ed_Pt9DbCMR3p8';

  // Optional: Redirect URL for password reset emails
  // For mobile apps, you might use deep links or custom URL schemes
  static const String redirectUrl = 'https://your-app.com/auth/callback';
}

// How to get your Supabase credentials:
// 1. Go to https://supabase.com/dashboard
// 2. Select your project (or create a new one)
// 3. Go to Settings > API
// 4. Copy the 'Project URL' and paste it as supabaseUrl
// 5. Copy the 'anon/public key' and paste it as supabaseAnonKey
//
// Note: The anon key is safe to use in client-side applications.
// It has limited permissions and is meant to be public.
