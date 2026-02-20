import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SupabaseConstants {
  // Load credentials from .env file, with --dart-define fallback for production
  // Web: Uses hardcoded values (no .env access in browser)
  // Mobile/Desktop: Uses .env file with --dart-define fallback
  static String get supabaseUrl {
    // Web: hardcoded (no .env access in browser)
    if (kIsWeb) {
      return 'https://fnvimtiikafwimnzzonu.supabase.co';
    }
    // Mobile/Desktop: existing logic
    return dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL');
  }

  static String get supabaseAnonKey {
    // Web: hardcoded (no .env access in browser)
    if (kIsWeb) {
      return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZudmltdGlpa2Fmd2ltbnp6b251Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NDA0MzQsImV4cCI6MjA4MzUxNjQzNH0.ccFELR1D1hahqG5rN21Dox2Cwxct_OXPqkglLXprL9s';
    }
    // Mobile/Desktop: existing logic
    return dotenv.env['SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment('SUPABASE_ANON_KEY');
  }

  // Storage buckets
  static String get selfiesBucket =>
      dotenv.env['SUPABASE_SELFIES_BUCKET'] ?? 'selfies';
  static String get taskSubmissionsBucket =>
      dotenv.env['SUPABASE_TASK_SUBMISSIONS_BUCKET'] ?? 'task-submissions';

  // Validate that required environment variables are set
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static void validateConfig() {
    if (!isConfigured) {
      throw Exception(
        'Supabase configuration missing. '
        'Please ensure SUPABASE_URL and SUPABASE_ANON_KEY are set in .env file.',
      );
    }
  }
}
