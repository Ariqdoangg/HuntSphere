import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/error_handler.dart';
import 'package:huntsphere/services/cache_service.dart';

/// Result class for service operations
class ServiceResult<T> {
  final T? data;
  final AppError? error;
  final bool isSuccess;

  const ServiceResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory ServiceResult.success(T data) {
    return ServiceResult._(data: data, isSuccess: true);
  }

  factory ServiceResult.failure(AppError error) {
    return ServiceResult._(error: error, isSuccess: false);
  }

  /// Transform the data if success
  ServiceResult<R> map<R>(R Function(T data) transform) {
    if (isSuccess && data != null) {
      return ServiceResult.success(transform(data as T));
    }
    return ServiceResult.failure(error!);
  }

  /// Get data or throw
  T get dataOrThrow {
    if (isSuccess && data != null) return data as T;
    throw Exception(error?.message ?? 'Unknown error');
  }

  /// Execute callback on success
  void whenSuccess(void Function(T data) callback) {
    if (isSuccess && data != null) {
      callback(data as T);
    }
  }

  /// Execute callback on failure
  void whenFailure(void Function(AppError error) callback) {
    if (!isSuccess && error != null) {
      callback(error!);
    }
  }
}

/// Facilitator model
class FacilitatorModel {
  final String id;
  final String name;
  final String email;
  final String userId;
  final DateTime createdAt;

  FacilitatorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.userId,
    required this.createdAt,
  });

  factory FacilitatorModel.fromJson(Map<String, dynamic> json) {
    return FacilitatorModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Authentication service for facilitators and auth state management
class AuthService {
  final SupabaseClient _client;
  final CacheService? _cache;

  AuthService(this._client, [this._cache]);

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get current user ID
  String? get currentUserId => currentUser?.id;

  /// Sign up a new facilitator
  Future<ServiceResult<User>> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return ServiceResult.failure(
          const AppError(
            message: 'Failed to create account. Please try again.',
            type: ErrorType.authentication,
          ),
        );
      }

      // Create facilitator record
      await _client.from('facilitators').insert({
        'user_id': response.user!.id,
        'name': name,
        'email': email,
      });

      return ServiceResult.success(response.user!);
    } catch (e) {
      debugPrint('AuthService.signUp error: $e');
      return ServiceResult.failure(ErrorHandler.handle(e, context: 'signing up'));
    }
  }

  /// Sign in an existing facilitator
  Future<ServiceResult<User>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return ServiceResult.failure(
          const AppError(
            message: 'Invalid email or password.',
            type: ErrorType.authentication,
          ),
        );
      }

      return ServiceResult.success(response.user!);
    } catch (e) {
      debugPrint('AuthService.signIn error: $e');
      return ServiceResult.failure(ErrorHandler.handle(e, context: 'signing in'));
    }
  }

  /// Sign out the current user and clear local caches
  Future<ServiceResult<void>> signOut() async {
    try {
      // Clear local caches before signing out
      await _cache?.clearAll();
      await _client.auth.signOut();
      return ServiceResult.success(null);
    } catch (e) {
      debugPrint('AuthService.signOut error: $e');
      return ServiceResult.failure(ErrorHandler.handle(e, context: 'signing out'));
    }
  }

  /// Get the current facilitator profile
  Future<ServiceResult<FacilitatorModel>> getFacilitatorProfile() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ServiceResult.failure(
          const AppError(
            message: 'Not authenticated',
            type: ErrorType.authentication,
          ),
        );
      }

      final response = await _client
          .from('facilitators')
          .select()
          .eq('user_id', userId)
          .single();

      return ServiceResult.success(FacilitatorModel.fromJson(response));
    } catch (e) {
      debugPrint('AuthService.getFacilitatorProfile error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading profile'),
      );
    }
  }

  /// Update facilitator profile
  Future<ServiceResult<FacilitatorModel>> updateProfile({
    required String name,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return ServiceResult.failure(
          const AppError(
            message: 'Not authenticated',
            type: ErrorType.authentication,
          ),
        );
      }

      final response = await _client
          .from('facilitators')
          .update({'name': name})
          .eq('user_id', userId)
          .select()
          .single();

      return ServiceResult.success(FacilitatorModel.fromJson(response));
    } catch (e) {
      debugPrint('AuthService.updateProfile error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'updating profile'),
      );
    }
  }

  /// Reset password
  Future<ServiceResult<void>> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return ServiceResult.success(null);
    } catch (e) {
      debugPrint('AuthService.resetPassword error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'resetting password'),
      );
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
