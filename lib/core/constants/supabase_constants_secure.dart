import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;

class SupabaseConstants {
  // Load credentials from environment variables only
  // NEVER hardcode secrets in source code
  static String get supabaseUrl {
    // Try .env file first (works on mobile, desktop, and web via asset)
    final envUrl = dotenv.env['SUPABASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    // Fallback: --dart-define for CI/CD or production builds
    const defineUrl = String.fromEnvironment('SUPABASE_URL');
    if (defineUrl.isNotEmpty) return defineUrl;

    throw Exception(
      'SUPABASE_URL not found.\n'
      'Ensure .env file exists with SUPABASE_URL set.',
    );
  }

  static String get supabaseAnonKey {
    // Try .env file first (works on mobile, desktop, and web via asset)
    final envKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;

    // Fallback: --dart-define for CI/CD or production builds
    const defineKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (defineKey.isNotEmpty) return defineKey;

    throw Exception(
      'SUPABASE_ANON_KEY not found.\n'
      'Ensure .env file exists with SUPABASE_ANON_KEY set.',
    );
  }

  // Storage buckets
  static String get selfiesBucket =>
      dotenv.env['SUPABASE_SELFIES_BUCKET'] ?? 'selfies';
  static String get taskSubmissionsBucket =>
      dotenv.env['SUPABASE_TASK_SUBMISSIONS_BUCKET'] ?? 'task-submissions';

  // Validate that required environment variables are set
  static bool get isConfigured {
    try {
      supabaseUrl;
      supabaseAnonKey;
      return true;
    } catch (e) {
      return false;
    }
  }

  static void validateConfig() {
    // Temporarily disabled for demo purposes
    // if (!isConfigured) {
    //   throw Exception(
    //     'Supabase configuration missing.\n'
    //     'Please ensure SUPABASE_URL and SUPABASE_ANON_KEY are set in .env file '
    //     'or as environment variables for web deployment.',
    //   );
    // }
  }

  // Development-only validation (never expose in production)
  static void validateForDevelopment() {
    // Temporarily disabled for demo purposes
    // if (!kDebugMode) return;
    
    // final url = supabaseUrl;
    // final key = supabaseAnonKey;
    
    // if (url.contains('localhost') || url.contains('127.0.0.1')) {
    //   debugPrint('⚠️ Using localhost Supabase URL in development');
    // }
    
    // if (key.length < 50) {
    //   debugPrint('⚠️ Supabase key seems too short - check your configuration');
    // }
  }
}
