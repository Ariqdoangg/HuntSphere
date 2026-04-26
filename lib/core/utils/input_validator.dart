import 'package:huntsphere/core/utils/result.dart';

/// Input validation utilities for HuntSphere
/// Provides comprehensive validation for user inputs
class InputValidator {
  InputValidator._();

  /// Validate activity name
  static Result<String> validateActivityName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return Failure(AppError(
        message: 'Activity name is required',
        type: ErrorType.validation,
      ));
    }

    final trimmedName = name.trim();
    
    if (trimmedName.length < 3) {
      return Failure(AppError(
        message: 'Activity name must be at least 3 characters',
        type: ErrorType.validation,
      ));
    }

    if (trimmedName.length > 100) {
      return Failure(AppError(
        message: 'Activity name must be less than 100 characters',
        type: ErrorType.validation,
      ));
    }

    // Check for special characters that might cause issues
    if (RegExp('[<>"\'&]').hasMatch(trimmedName)) {
      return Failure(AppError(
        message: 'Activity name contains invalid characters',
        type: ErrorType.validation,
      ));
    }

    return Success(trimmedName);
  }

  /// Validate team name
  static Result<String> validateTeamName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return Failure(AppError(
        message: 'Team name is required',
        type: ErrorType.validation,
      ));
    }

    final trimmedName = name.trim();
    
    if (trimmedName.length < 2) {
      return Failure(AppError(
        message: 'Team name must be at least 2 characters',
        type: ErrorType.validation,
      ));
    }

    if (trimmedName.length > 50) {
      return Failure(AppError(
        message: 'Team name must be less than 50 characters',
        type: ErrorType.validation,
      ));
    }

    if (RegExp('[<>"\'&]').hasMatch(trimmedName)) {
      return Failure(AppError(
        message: 'Team name contains invalid characters',
        type: ErrorType.validation,
      ));
    }

    return Success(trimmedName);
  }

  /// Validate duration in minutes
  static Result<int> validateDuration(int? minutes) {
    if (minutes == null) {
      return Failure(AppError(
        message: 'Duration is required',
        type: ErrorType.validation,
      ));
    }

    if (minutes < 5) {
      return Failure(AppError(
        message: 'Activity must be at least 5 minutes',
        type: ErrorType.validation,
      ));
    }

    if (minutes > 480) { // 8 hours max
      return Failure(AppError(
        message: 'Activity must be less than 8 hours',
        type: ErrorType.validation,
      ));
    }

    return Success(minutes);
  }

  /// Validate join code
  static Result<String> validateJoinCode(String? code) {
    if (code == null || code.trim().isEmpty) {
      return Failure(AppError(
        message: 'Join code is required',
        type: ErrorType.validation,
      ));
    }

    final trimmedCode = code.trim().toUpperCase();
    
    if (trimmedCode.length != 6) {
      return Failure(AppError(
        message: 'Join code must be exactly 6 characters',
        type: ErrorType.validation,
      ));
    }

    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(trimmedCode)) {
      return Failure(AppError(
        message: 'Join code must contain only letters and numbers',
        type: ErrorType.validation,
      ));
    }

    return Success(trimmedCode);
  }

  /// Validate participant name
  static Result<String> validateParticipantName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return Failure(AppError(
        message: 'Name is required',
        type: ErrorType.validation,
      ));
    }

    final trimmedName = name.trim();
    
    if (trimmedName.length < 2) {
      return Failure(AppError(
        message: 'Name must be at least 2 characters',
        type: ErrorType.validation,
      ));
    }

    if (trimmedName.length > 30) {
      return Failure(AppError(
        message: 'Name must be less than 30 characters',
        type: ErrorType.validation,
      ));
    }

    if (RegExp('[<>"\'&]').hasMatch(trimmedName)) {
      return Failure(AppError(
        message: 'Name contains invalid characters',
        type: ErrorType.validation,
      ));
    }

    return Success(trimmedName);
  }

  /// Validate email format
  static Result<String> validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return Failure(AppError(
        message: 'Email is required',
        type: ErrorType.validation,
      ));
    }

    final trimmedEmail = email.trim().toLowerCase();
    
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(trimmedEmail)) {
      return Failure(AppError(
        message: 'Please enter a valid email address',
        type: ErrorType.validation,
      ));
    }

    return Success(trimmedEmail);
  }

  /// Validate points value
  static Result<int> validatePoints(int? points) {
    if (points == null) {
      return Failure(AppError(
        message: 'Points value is required',
        type: ErrorType.validation,
      ));
    }

    if (points < 0) {
      return Failure(AppError(
        message: 'Points cannot be negative',
        type: ErrorType.validation,
      ));
    }

    if (points > 9999) {
      return Failure(AppError(
        message: 'Points value is too high',
        type: ErrorType.validation,
      ));
    }

    return Success(points);
  }

  /// Sanitize text input for database
  static String sanitizeText(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp('["\'&]'), '') // Remove problematic chars
        .substring(0, 500); // Limit length
  }

  /// Validate and sanitize text
  static Result<String> validateAndSanitizeText(String? input, {
    required String fieldName,
    int minLength = 1,
    int maxLength = 100,
  }) {
    if (input == null || input.trim().isEmpty) {
      return Failure(AppError(
        message: '$fieldName is required',
        type: ErrorType.validation,
      ));
    }

    final trimmed = input.trim();
    
    if (trimmed.length < minLength) {
      return Failure(AppError(
        message: '$fieldName must be at least $minLength characters',
        type: ErrorType.validation,
      ));
    }

    if (trimmed.length > maxLength) {
      return Failure(AppError(
        message: '$fieldName must be less than $maxLength characters',
        type: ErrorType.validation,
      ));
    }

    final sanitized = sanitizeText(trimmed);
    if (sanitized.length != trimmed.length) {
      return Failure(AppError(
        message: '$fieldName contains invalid characters',
        type: ErrorType.validation,
      ));
    }

    return Success(sanitized);
  }
}

/// Validation result for form fields
class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;

  const ValidationResult({
    required this.isValid,
    this.errors = const {},
  });

  const ValidationResult.valid() : isValid = true, errors = const {};
  const ValidationResult.invalid(this.errors) : isValid = false;

  String? getErrorForField(String field) => errors[field];

  bool hasErrorForField(String field) => errors.containsKey(field);

  static ValidationResult success() => const ValidationResult.valid();
  static ValidationResult failure(Map<String, String> errors) =>
      ValidationResult.invalid(errors);
}
