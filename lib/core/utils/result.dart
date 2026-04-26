/// Standardized result type for operations that can succeed or fail
/// Replaces the current ServiceResult with a proper sealed class pattern
sealed class Result<T> {
  const Result();

  /// Returns true if this is a Success
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a Failure
  bool get isFailure => this is Failure<T>;

  /// Gets the success value or null
  T? get data => switch (this) {
    Success<T>(data: final d) => d,
    _ => null,
  };

  /// Gets the error or null
  AppError? get error => switch (this) {
    Failure<T>(error: final e) => e,
    _ => null,
  };

  /// Execute a function based on success/failure
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    return switch (this) {
      Success<T>(data: final d) => success(d),
      Failure<T>(error: final e) => failure(e),
      _ => throw StateError('Invalid Result state'),
    };
  }

  /// Execute a function only on success
  Result<T> onSuccess(void Function(T data) action) {
    if (this is Success<T>) {
      action((this as Success<T>).data);
    }
    return this;
  }

  /// Execute a function only on failure
  Result<T> onFailure(void Function(AppError error) action) {
    if (this is Failure<T>) {
      action((this as Failure<T>).error);
    }
    return this;
  }

  /// Transform the success value
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T>(data: final d) => Success(transform(d)),
      Failure<T>(error: final e) => Failure<R>(e),
      _ => throw StateError('Invalid Result state'),
    };
  }

  /// FlatMap for chaining operations
  Result<R> flatMap<R>(Result<R> Function(T data) transform) {
    return switch (this) {
      Success<T>(data: final d) => transform(d),
      Failure<T>(error: final e) => Failure<R>(e),
      _ => throw StateError('Invalid Result state'),
    };
  }
}

/// Success variant containing the data
class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success(data: $data)';
}

/// Failure variant containing the error
class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);

  @override
  String toString() => 'Failure(error: $error)';
}

/// Application error with type and message
class AppError {
  final String message;
  final String? technicalDetails;
  final ErrorType type;
  final StackTrace? stackTrace;

  const AppError({
    required this.message,
    this.technicalDetails,
    this.type = ErrorType.unknown,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

/// Types of errors that can occur
enum ErrorType {
  network,
  authentication,
  validation,
  notFound,
  permission,
  server,
  timeout,
  cache,
  unknown,
}

/// Extension to create Results from Futures
extension FutureResult<T> on Future<T> {
  Future<Result<T>> toResult({
    ErrorType errorType = ErrorType.unknown,
    String? errorMessage,
  }) async {
    try {
      final data = await this;
      return Success(data);
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: errorMessage ?? e.toString(),
        technicalDetails: e.toString(),
        type: errorType,
        stackTrace: stackTrace,
      ));
    }
  }
}
