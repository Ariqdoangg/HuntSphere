import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:huntsphere/core/utils/result.dart';

/// Retry policy with exponential backoff for resilient API calls
class RetryPolicy {
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final List<ErrorType> retryableErrors;

  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.retryableErrors = const [
      ErrorType.network,
      ErrorType.timeout,
      ErrorType.server,
    ],
  });

  /// Execute an operation with retry logic
  Future<Result<T>> execute<T>(Future<Result<T>> Function() operation) async {
    int attempts = 0;
    Duration currentDelay = baseDelay;

    while (attempts < maxRetries) {
      attempts++;

      try {
        final result = await operation();

        // If success, return immediately
        if (result.isSuccess) {
          return result;
        }

        // If failure, check if we should retry
        final error = result.error;
        if (error == null || !retryableErrors.contains(error.type)) {
          return result; // Non-retryable error, return immediately
        }

        // If this was the last attempt, return the failure
        if (attempts >= maxRetries) {
          debugPrint('RetryPolicy: Max retries ($maxRetries) exceeded');
          return result;
        }

        // Wait before retrying
        debugPrint('RetryPolicy: Attempt $attempts failed, retrying in ${currentDelay.inSeconds}s');
        await Future.delayed(currentDelay);

        // Increase delay for next attempt (exponential backoff)
        currentDelay = Duration(
          milliseconds: min(
            (currentDelay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
      } catch (e, stackTrace) {
        // Unexpected exception, wrap in Result
        if (attempts >= maxRetries) {
          return Failure(AppError(
            message: 'Operation failed after $maxRetries attempts',
            technicalDetails: e.toString(),
            type: ErrorType.unknown,
            stackTrace: stackTrace,
          ));
        }

        debugPrint('RetryPolicy: Unexpected error on attempt $attempts: $e');
        await Future.delayed(currentDelay);
        currentDelay = Duration(
          milliseconds: min(
            (currentDelay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
      }
    }

    return Failure(AppError(
      message: 'Operation failed after $maxRetries attempts',
      type: ErrorType.unknown,
    ));
  }
}

/// Resilient API client that wraps repository calls with retry logic
class ResilientApiClient {
  final RetryPolicy _retryPolicy;

  ResilientApiClient({RetryPolicy? retryPolicy})
      : _retryPolicy = retryPolicy ?? const RetryPolicy();

  /// Execute an operation with automatic retry
  Future<Result<T>> execute<T>(Future<Result<T>> Function() operation) async {
    return await _retryPolicy.execute(operation);
  }

  /// Execute with custom retry policy
  Future<Result<T>> executeWithPolicy<T>(
    Future<Result<T>> Function() operation, {
    required RetryPolicy policy,
  }) async {
    return await policy.execute(operation);
  }
}

/// Extension to add retry capability to any repository
extension RepositoryRetryExtension<T> on Future<Result<T>> {
  /// Add retry logic to any repository operation
  Future<Result<T>> withRetry({RetryPolicy? policy}) async {
    final retryPolicy = policy ?? const RetryPolicy();
    return await retryPolicy.execute(() => this);
  }
}

/// Circuit breaker pattern for preventing cascade failures
class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
  });

  bool get isOpen => _isOpen;
  bool get isClosed => !_isOpen;
  bool get isHalfOpen => _isOpen && _shouldAttemptReset();

  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return true;
    return DateTime.now().difference(_lastFailureTime!) > resetTimeout;
  }

  void recordSuccess() {
    _failureCount = 0;
    _isOpen = false;
    _lastFailureTime = null;
  }

  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _isOpen = true;
      debugPrint('CircuitBreaker: Opened after $failureThreshold failures');
    }
  }

  Future<Result<T>> execute<T>(Future<Result<T>> Function() operation) async {
    if (_isOpen && !_shouldAttemptReset()) {
      return Failure(AppError(
        message: 'Circuit breaker is open - service temporarily unavailable',
        type: ErrorType.server,
      ));
    }

    // Try to execute (half-open state allows one test request)
    final result = await operation();

    result.when(
      success: (_) => recordSuccess(),
      failure: (_) => recordFailure(),
    );

    return result;
  }
}
