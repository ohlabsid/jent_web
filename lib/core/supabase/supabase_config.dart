import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection details. Values come from `--dart-define` so no
/// secret is committed to the repo:
///
/// flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co
///             --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// The anon key is public by design (it ships inside the app); access
/// control lives in the table RLS policies on the Supabase dashboard.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Initializes the shared Supabase client. Skipped when the defines
  /// are missing so the app keeps working fully offline.
  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }
}
