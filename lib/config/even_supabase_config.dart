import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection settings are supplied at build/run time.
///
/// Never hard-code a Supabase secret/service-role key in the Flutter app.
/// The publishable key is intended for client use when Row Level Security
/// policies protect every exposed table and function.
class EvenSupabaseConfig {
  EvenSupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured =>
      url.startsWith('https://') && publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(
      url: url,
      anonKey: publishableKey,
    );
  }

  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;
}
