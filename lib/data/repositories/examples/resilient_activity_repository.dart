import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/core/utils/retry_policy.dart';
import 'package:huntsphere/domain/repositories/activity_repository.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';

/// Example repository implementation with retry logic
/// Shows how to use ResilientApiClient for automatic retry on failures
class ResilientActivityRepository implements ActivityRepository {
  final SupabaseClient _client;
  final ResilientApiClient _resilientClient;

  ResilientActivityRepository(
    this._client, {
    ResilientApiClient? resilientClient,
  }) : _resilientClient = resilientClient ?? ResilientApiClient();

  @override
  Future<Result<List<ActivityModel>>> getActivities(String userId) async {
    return await _resilientClient.execute(() async {
      try {
        final response = await _client
            .from('activities')
            .select()
            .eq('created_by', userId)
            .order('created_at', ascending: false);

        final activities = (response as List)
            .map((json) => ActivityModel.fromJson(json))
            .toList();

        return Success(activities);
      } on PostgrestException catch (e) {
        return Failure(AppError(
          message: 'Failed to load activities',
          technicalDetails: e.message,
          type: _mapPostgrestError(e),
        ));
      } catch (e, stackTrace) {
        return Failure(AppError(
          message: 'Unexpected error loading activities',
          technicalDetails: e.toString(),
          type: ErrorType.unknown,
          stackTrace: stackTrace,
        ));
      }
    });
  }

  @override
  Future<Result<ActivityModel>> getActivity(String id) async {
    return await _resilientClient.execute(() async {
      try {
        final response = await _client
            .from('activities')
            .select()
            .eq('id', id)
            .single();

        return Success(ActivityModel.fromJson(response));
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST116') {
          return Failure(AppError(
            message: 'Activity not found',
            type: ErrorType.notFound,
          ));
        }
        return Failure(AppError(
          message: 'Failed to load activity',
          technicalDetails: e.message,
          type: _mapPostgrestError(e),
        ));
      } catch (e, stackTrace) {
        return Failure(AppError(
          message: 'Unexpected error loading activity',
          technicalDetails: e.toString(),
          type: ErrorType.unknown,
          stackTrace: stackTrace,
        ));
      }
    });
  }

  @override
  Future<Result<ActivityModel>> createActivity(ActivityModel activity) async {
    return await _resilientClient.execute(() async {
      try {
        final response = await _client
            .from('activities')
            .insert(activity.toJson())
            .select()
            .single();

        return Success(ActivityModel.fromJson(response));
      } on PostgrestException catch (e) {
        return Failure(AppError(
          message: 'Failed to create activity',
          technicalDetails: e.message,
          type: _mapPostgrestError(e),
        ));
      } catch (e, stackTrace) {
        return Failure(AppError(
          message: 'Unexpected error creating activity',
          technicalDetails: e.toString(),
          type: ErrorType.unknown,
          stackTrace: stackTrace,
        ));
      }
    });
  }

  @override
  Future<Result<ActivityModel>> updateActivity(ActivityModel activity) async {
    return await _resilientClient.execute(() async {
      try {
        final response = await _client
            .from('activities')
            .update(activity.toJson())
            .eq('id', activity.id!)
            .select()
            .single();

        return Success(ActivityModel.fromJson(response));
      } on PostgrestException catch (e) {
        return Failure(AppError(
          message: 'Failed to update activity',
          technicalDetails: e.message,
          type: _mapPostgrestError(e),
        ));
      } catch (e, stackTrace) {
        return Failure(AppError(
          message: 'Unexpected error updating activity',
          technicalDetails: e.toString(),
          type: ErrorType.unknown,
          stackTrace: stackTrace,
        ));
      }
    });
  }

  @override
  Future<Result<void>> deleteActivity(String id) async {
    return await _resilientClient.execute(() async {
      try {
        await _client.from('activities').delete().eq('id', id);
        return const Success(null);
      } on PostgrestException catch (e) {
        return Failure(AppError(
          message: 'Failed to delete activity',
          technicalDetails: e.message,
          type: _mapPostgrestError(e),
        ));
      } catch (e, stackTrace) {
        return Failure(AppError(
          message: 'Unexpected error deleting activity',
          technicalDetails: e.toString(),
          type: ErrorType.unknown,
          stackTrace: stackTrace,
        ));
      }
    });
  }

  @override
  Future<Result<List<ActivityModel>>> getActivitiesByStatus(
    String userId,
    String status,
  ) async {
    return await _resilientClient.execute(() async {
      try {
        final response = await _client
            .from('activities')
            .select()
            .eq('created_by', userId)
            .eq('status', status)
            .order('created_at', ascending: false);

        final activities = (response as List)
            .map((json) => ActivityModel.fromJson(json))
            .toList();

        return Success(activities);
      } on PostgrestException catch (e) {
        return Failure(AppError(
          message: 'Failed to load activities by status',
          technicalDetails: e.message,
          type: _mapPostgrestError(e),
        ));
      } catch (e, stackTrace) {
        return Failure(AppError(
          message: 'Unexpected error loading activities',
          technicalDetails: e.toString(),
          type: ErrorType.unknown,
          stackTrace: stackTrace,
        ));
      }
    });
  }

  /// Map PostgrestException to appropriate ErrorType
  ErrorType _mapPostgrestError(PostgrestException e) {
    // Map error codes to appropriate types
    switch (e.code) {
      case 'PGRST116': // Not found
        return ErrorType.notFound;
      case '23505': // Unique violation
        return ErrorType.validation;
      case '23503': // Foreign key violation
        return ErrorType.validation;
      case '42501': // Insufficient privilege
        return ErrorType.permission;
      case 'PGRST301': // JWT expired
      case 'PGRST302': // JWT invalid
        return ErrorType.authentication;
      default:
        if (e.message.contains('network') || e.message.contains('connection')) {
          return ErrorType.network;
        }
        if (e.message.contains('timeout')) {
          return ErrorType.timeout;
        }
        return ErrorType.server;
    }
  }

  /// Example: Using custom retry policy for specific operations
  Future<Result<ActivityModel>> createActivityWithCustomRetry(
    ActivityModel activity,
  ) async {
    final customPolicy = RetryPolicy(
      maxRetries: 5, // More retries for critical operations
      baseDelay: Duration(seconds: 2), // Longer initial delay
      maxDelay: Duration(seconds: 60), // Longer max delay
      retryableErrors: [
        ErrorType.network,
        ErrorType.timeout,
        ErrorType.server,
      ],
    );

    return await _resilientClient.executeWithPolicy(
      () async => await createActivity(activity),
      policy: customPolicy,
    );
  }
}
