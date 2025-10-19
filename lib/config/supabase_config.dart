// Supabase configuration
// IMPORTANT: Replace these with your actual Supabase project credentials
class SupabaseConfig {
  // Your Supabase project URL
  static const String supabaseUrl = 'https://hdjsoucuqegosvasovla.supabase.co';

  // Your Supabase anon/public key
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkanNvdWN1cWVnb3N2YXNvdmxhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA4ODc5NjAsImV4cCI6MjA3NjQ2Mzk2MH0.yKSiX5jD5oumdhzmnplkNS3ghzj_4Ed_Pt9DbCMR3p8';

  // Optional: Redirect URL for password reset
  static const String redirectUrl = 'YOUR_REDIRECT_URL_HERE';
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