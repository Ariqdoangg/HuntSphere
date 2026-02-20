/// Centralized validation utilities for HuntSphere
/// Use these validators across all screens for consistent validation logic

class Validators {
  // Private constructor to prevent instantiation
  Validators._();

  // ============ Email Validation ============

  /// Validates email format using a comprehensive regex pattern
  /// Returns null if valid, error message if invalid
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final email = value.trim();

    // RFC 5322 compliant email regex (simplified)
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // ============ Password Validation ============

  /// Validates password strength
  /// Returns null if valid, error message if invalid
  static String? validatePassword(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }

    return null;
  }

  /// Validates password confirmation matches
  static String? validatePasswordConfirm(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  // ============ Name Validation ============

  /// Validates a name field (person name, activity name, etc.)
  /// Returns null if valid, error message if invalid
  static String? validateName(
    String? value, {
    String fieldName = 'Name',
    int minLength = 2,
    int maxLength = 100,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final name = value.trim();

    if (name.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (name.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }

    // Check for invalid characters (allow letters, numbers, spaces, hyphens, apostrophes)
    final nameRegex = RegExp(r"^[a-zA-Z0-9\s\-']+$");
    if (!nameRegex.hasMatch(name)) {
      return '$fieldName contains invalid characters';
    }

    return null;
  }

  // ============ Join Code Validation ============

  /// Validates activity join code format
  /// Expected format: 6 alphanumeric characters (uppercase)
  static String? validateJoinCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Join code is required';
    }

    final code = value.trim().toUpperCase();

    if (code.length != 6) {
      return 'Join code must be exactly 6 characters';
    }

    // Only alphanumeric characters allowed
    final codeRegex = RegExp(r'^[A-Z0-9]{6}$');
    if (!codeRegex.hasMatch(code)) {
      return 'Join code must contain only letters and numbers';
    }

    return null;
  }

  // ============ Duration Validation ============

  /// Validates activity duration in minutes
  /// Returns null if valid, error message if invalid
  static String? validateDuration(
    String? value, {
    int minMinutes = 5,
    int maxMinutes = 480, // 8 hours max
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Duration is required';
    }

    final duration = int.tryParse(value.trim());

    if (duration == null) {
      return 'Please enter a valid number';
    }

    if (duration < minMinutes) {
      return 'Duration must be at least $minMinutes minutes';
    }

    if (duration > maxMinutes) {
      return 'Duration cannot exceed $maxMinutes minutes';
    }

    return null;
  }

  // ============ Coordinate Validation ============

  /// Validates latitude value (-90 to 90)
  static String? validateLatitude(double? value) {
    if (value == null) {
      return 'Latitude is required';
    }

    if (value < -90 || value > 90) {
      return 'Latitude must be between -90 and 90';
    }

    return null;
  }

  /// Validates longitude value (-180 to 180)
  static String? validateLongitude(double? value) {
    if (value == null) {
      return 'Longitude is required';
    }

    if (value < -180 || value > 180) {
      return 'Longitude must be between -180 and 180';
    }

    return null;
  }

  // ============ Geofence Radius Validation ============

  /// Validates geofence radius in meters
  static String? validateRadius(
    String? value, {
    double minRadius = 5,
    double maxRadius = 500,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Radius is required';
    }

    final radius = double.tryParse(value.trim());

    if (radius == null) {
      return 'Please enter a valid number';
    }

    if (radius < minRadius) {
      return 'Radius must be at least $minRadius meters';
    }

    if (radius > maxRadius) {
      return 'Radius cannot exceed $maxRadius meters';
    }

    return null;
  }

  // ============ Points Validation ============

  /// Validates point values for tasks/checkpoints
  static String? validatePoints(
    String? value, {
    int minPoints = 0,
    int maxPoints = 1000,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Points value is required';
    }

    final points = int.tryParse(value.trim());

    if (points == null) {
      return 'Please enter a valid number';
    }

    if (points < minPoints) {
      return 'Points must be at least $minPoints';
    }

    if (points > maxPoints) {
      return 'Points cannot exceed $maxPoints';
    }

    return null;
  }

  // ============ Generic Required Field ============

  /// Validates that a field is not empty
  static String? validateRequired(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // ============ Answer/Text Input Validation ============

  /// Validates text input with length constraints
  static String? validateTextInput(
    String? value, {
    String fieldName = 'Input',
    int? minLength,
    int? maxLength,
    bool required = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$fieldName is required' : null;
    }

    final text = value.trim();

    if (minLength != null && text.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (maxLength != null && text.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }

    return null;
  }

  // ============ URL Validation ============

  /// Validates URL format
  static String? validateUrl(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'URL is required' : null;
    }

    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );

    if (!urlRegex.hasMatch(value.trim())) {
      return 'Please enter a valid URL';
    }

    return null;
  }
}
