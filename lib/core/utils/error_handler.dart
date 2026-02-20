import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized error handling for HuntSphere
/// Provides consistent error messages and logging across the app

class AppError {
  final String message;
  final String? technicalDetails;
  final ErrorType type;

  const AppError({
    required this.message,
    this.technicalDetails,
    this.type = ErrorType.unknown,
  });

  @override
  String toString() => message;
}

enum ErrorType {
  network,
  authentication,
  validation,
  notFound,
  permission,
  server,
  timeout,
  unknown,
}

class ErrorHandler {
  ErrorHandler._();

  /// Converts any exception to a user-friendly AppError
  static AppError handle(dynamic error, {String? context}) {
    _logError(error, context);

    if (error is AuthException) {
      return _handleAuthError(error);
    }

    if (error is PostgrestException) {
      return _handlePostgrestError(error);
    }

    if (error is StorageException) {
      return _handleStorageError(error);
    }

    if (_isNetworkError(error)) {
      return const AppError(
        message: 'No internet connection. Please check your network.',
        type: ErrorType.network,
      );
    }

    if (_isTimeoutError(error)) {
      return const AppError(
        message: 'Request timed out. Please try again.',
        type: ErrorType.timeout,
      );
    }

    return AppError(
      message: context != null
          ? 'Something went wrong while $context. Please try again.'
          : 'Something went wrong. Please try again.',
      technicalDetails: error.toString(),
      type: ErrorType.unknown,
    );
  }

  static AppError _handleAuthError(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid password')) {
      return const AppError(
        message: 'Invalid email or password. Please try again.',
        type: ErrorType.authentication,
      );
    }

    if (message.contains('email not confirmed')) {
      return const AppError(
        message: 'Please verify your email before signing in.',
        type: ErrorType.authentication,
      );
    }

    if (message.contains('user already registered') ||
        message.contains('already been registered')) {
      return const AppError(
        message: 'An account with this email already exists.',
        type: ErrorType.authentication,
      );
    }

    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return const AppError(
        message: 'Too many attempts. Please wait and try again.',
        type: ErrorType.authentication,
      );
    }

    if (message.contains('session') || message.contains('refresh token')) {
      return const AppError(
        message: 'Your session has expired. Please sign in again.',
        type: ErrorType.authentication,
      );
    }

    return AppError(
      message: 'Authentication failed. Please try again.',
      technicalDetails: error.message,
      type: ErrorType.authentication,
    );
  }

  static AppError _handlePostgrestError(PostgrestException error) {
    final code = error.code;

    switch (code) {
      case '23505':
        return const AppError(
          message: 'This record already exists.',
          type: ErrorType.validation,
        );
      case '23503':
        return const AppError(
          message: 'Referenced record not found.',
          type: ErrorType.notFound,
        );
      case '42501':
        return const AppError(
          message: 'You do not have permission to perform this action.',
          type: ErrorType.permission,
        );
      case 'PGRST116':
        return const AppError(
          message: 'The requested item was not found.',
          type: ErrorType.notFound,
        );
      default:
        return AppError(
          message: 'A database error occurred. Please try again.',
          technicalDetails: error.message,
          type: ErrorType.server,
        );
    }
  }

  static AppError _handleStorageError(StorageException error) {
    final message = error.message.toLowerCase();

    if (message.contains('not found') || message.contains('does not exist')) {
      return const AppError(
        message: 'File not found.',
        type: ErrorType.notFound,
      );
    }

    if (message.contains('permission') || message.contains('unauthorized')) {
      return const AppError(
        message: 'You do not have permission to access this file.',
        type: ErrorType.permission,
      );
    }

    if (message.contains('size') || message.contains('too large')) {
      return const AppError(
        message: 'File is too large. Please choose a smaller file.',
        type: ErrorType.validation,
      );
    }

    return AppError(
      message: 'Failed to upload file. Please try again.',
      technicalDetails: error.message,
      type: ErrorType.server,
    );
  }

  static bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection refused') ||
        errorString.contains('no internet') ||
        errorString.contains('unreachable');
  }

  static bool _isTimeoutError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout') || errorString.contains('timed out');
  }

  static void _logError(dynamic error, String? context) {
    assert(() {
      debugPrint('====== ERROR${context != null ? " [$context]" : ""} ======');
      debugPrint('Type: ${error.runtimeType}');
      debugPrint('Message: $error');
      if (error is Error) {
        debugPrint('Stack: ${error.stackTrace}');
      }
      debugPrint('====== END ERROR ======');
      return true;
    }());
  }

  /// Show error message using SnackBar
  static void showError(
    BuildContext context,
    dynamic error, {
    String? contextMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    final appError = handle(error, context: contextMessage);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForErrorType(appError.type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appError.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _getColorForErrorType(appError.type),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white70,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success message using SnackBar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: duration,
      ),
    );
  }

  /// Show info message using SnackBar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: duration,
      ),
    );
  }

  static IconData _getIconForErrorType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock_outline;
      case ErrorType.validation:
        return Icons.warning_amber;
      case ErrorType.notFound:
        return Icons.search_off;
      case ErrorType.permission:
        return Icons.block;
      case ErrorType.server:
        return Icons.cloud_off;
      case ErrorType.timeout:
        return Icons.timer_off;
      case ErrorType.unknown:
        return Icons.error_outline;
    }
  }

  static Color _getColorForErrorType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return const Color(0xFF795548);
      case ErrorType.authentication:
        return const Color(0xFFE91E63);
      case ErrorType.validation:
        return const Color(0xFFFF9800);
      case ErrorType.notFound:
        return const Color(0xFF607D8B);
      case ErrorType.permission:
        return const Color(0xFFF44336);
      case ErrorType.server:
        return const Color(0xFF9C27B0);
      case ErrorType.timeout:
        return const Color(0xFF3F51B5);
      case ErrorType.unknown:
        return const Color(0xFFF44336);
    }
  }
}
