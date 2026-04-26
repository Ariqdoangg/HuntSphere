import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/constants/supabase_constants_secure.dart';
import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/core/utils/input_validator.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/services/cache_service.dart';

/// Refactored Activity service with validation and proper error handling
class ActivityService {
  final SupabaseClient _client;
  final CacheService _cache;

  ActivityService(this._client, this._cache);

  /// Get current user ID with proper null checking
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Get all activities for the current facilitator
  Future<Result<List<ActivityModel>>> getActivities({
    bool forceRefresh = false,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      return Failure(AppError(
        message: 'You must be logged in to view activities',
        type: ErrorType.authentication,
      ));
    }

    return await getActivitiesByUserId(userId, forceRefresh: forceRefresh);
  }

  /// Get activities by user ID (internal method)
  Future<Result<List<ActivityModel>>> getActivitiesByUserId(
    String userId, {
    bool forceRefresh = false,
  }) async {
    try {
      // Try cache first
      if (!forceRefresh) {
        final cached = _cache.getCachedActivities(userId);
        if (cached != null) {
          debugPrint('ActivityService: Using cached activities for user $userId');
          final activities = cached.map((json) => ActivityModel.fromJson(json)).toList();
          return Success(activities);
        }
      }

      final response = await _client
          .from('activities')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false)
          .limit(50); // Add pagination limit

      final activities = (response as List)
          .map((json) => ActivityModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Update cache
      await _cache.cacheActivities(
        userId,
        response.cast<Map<String, dynamic>>(),
      );

      return Success(activities);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to load activities',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading activities',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get a single activity by ID
  Future<Result<ActivityModel>> getActivity(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    try {
      // Validate input
      final idValidation = InputValidator.validateAndSanitizeText(
        activityId,
        fieldName: 'Activity ID',
        minLength: 1,
        maxLength: 50,
      );
      if (idValidation.isFailure) {
        return Failure(idValidation.error!);
      }

      // Try cache first
      if (!forceRefresh) {
        final cached = _cache.getCachedActivity(activityId);
        if (cached != null) {
          return Success(ActivityModel.fromJson(cached));
        }
      }

      final response = await _client
          .from('activities')
          .select()
          .eq('id', activityId)
          .single();

      await _cache.cacheActivity(activityId, response);

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
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get activity by join code
  Future<Result<ActivityModel>> getActivityByJoinCode(String joinCode) async {
    try {
      // Validate input
      final codeValidation = InputValidator.validateJoinCode(joinCode);
      if (codeValidation.isFailure) {
        return Failure(codeValidation.error!);
      }

      final response = await _client
          .from('activities')
          .select()
          .eq('join_code', codeValidation.data!)
          .single();

      return Success(ActivityModel.fromJson(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return Failure(AppError(
          message: 'Invalid join code',
          type: ErrorType.notFound,
        ));
      }
      return Failure(AppError(
        message: 'Failed to find activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error finding activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Create a new activity with validation
  Future<Result<ActivityModel>> createActivity({
    required String name,
    required int durationMinutes,
    String? joinCode,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      return Failure(AppError(
        message: 'You must be logged in to create activities',
        type: ErrorType.authentication,
      ));
    }

    try {
      // Validate inputs
      final nameValidation = InputValidator.validateActivityName(name);
      if (nameValidation.isFailure) {
        return Failure(nameValidation.error!);
      }

      final durationValidation = InputValidator.validateDuration(durationMinutes);
      if (durationValidation.isFailure) {
        return Failure(durationValidation.error!);
      }

      // Generate join code if not provided
      final code = joinCode ?? _generateJoinCode();

      final data = {
        'name': nameValidation.data!,
        'join_code': code,
        'total_duration_minutes': durationValidation.data!,
        'status': 'setup',
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('activities')
          .insert(data)
          .select()
          .single();

      // Invalidate user's activities cache
      await _cache.clearActivitiesCache(userId);

      return Success(ActivityModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to create activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error creating activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update an activity with validation
  Future<Result<ActivityModel>> updateActivity(ActivityModel activity) async {
    try {
      // Validate activity ID
      if (activity.id == null || activity.id!.isEmpty) {
        return Failure(AppError(
          message: 'Activity ID is required',
          type: ErrorType.validation,
        ));
      }

      // Validate name if provided
      if (activity.name != null) {
        final nameValidation = InputValidator.validateActivityName(activity.name!);
        if (nameValidation.isFailure) {
          return Failure(nameValidation.error!);
        }
      }

      final response = await _client
          .from('activities')
          .update(activity.toJson())
          .eq('id', activity.id!)
          .select()
          .single();

      // Invalidate caches
      await _cache.invalidateActivityCaches(activity.id!);
      if (activity.createdBy != null) {
        await _cache.clearActivitiesCache(activity.createdBy!);
      }

      return Success(ActivityModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to update activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error updating activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Delete an activity
  Future<Result<void>> deleteActivity(String activityId) async {
    try {
      // Validate input
      final idValidation = InputValidator.validateAndSanitizeText(
        activityId,
        fieldName: 'Activity ID',
        minLength: 1,
        maxLength: 50,
      );
      if (idValidation.isFailure) {
        return Failure(idValidation.error!);
      }

      await _client.from('activities').delete().eq('id', activityId);

      // Invalidate caches
      await _cache.invalidateActivityCaches(activityId);

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to delete activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error deleting activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Start an activity
  Future<Result<ActivityModel>> startActivity(String activityId) async {
    try {
      // Validate input
      final idValidation = InputValidator.validateAndSanitizeText(
        activityId,
        fieldName: 'Activity ID',
        minLength: 1,
        maxLength: 50,
      );
      if (idValidation.isFailure) {
        return Failure(idValidation.error!);
      }

      final response = await _client
          .from('activities')
          .update({
            'status': 'active',
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', activityId)
          .select()
          .single();

      await _cache.invalidateActivityCaches(activityId);

      return Success(ActivityModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to start activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error starting activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// End an activity
  Future<Result<ActivityModel>> endActivity(String activityId) async {
    try {
      // Validate input
      final idValidation = InputValidator.validateAndSanitizeText(
        activityId,
        fieldName: 'Activity ID',
        minLength: 1,
        maxLength: 50,
      );
      if (idValidation.isFailure) {
        return Failure(idValidation.error!);
      }

      final response = await _client
          .from('activities')
          .update({
            'status': 'completed',
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', activityId)
          .select()
          .single();

      await _cache.invalidateActivityCaches(activityId);

      return Success(ActivityModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to end activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error ending activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Generate a unique join code using cryptographically secure random
  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Get checkpoints for an activity
  Future<Result<List<Map<String, dynamic>>>> getCheckpoints(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    try {
      // Validate input
      final idValidation = InputValidator.validateAndSanitizeText(
        activityId,
        fieldName: 'Activity ID',
        minLength: 1,
        maxLength: 50,
      );
      if (idValidation.isFailure) {
        return Failure(idValidation.error!);
      }

      if (!forceRefresh) {
        final cached = _cache.getCachedCheckpoints(activityId);
        if (cached != null) {
          return Success(cached);
        }
      }

      final response = await _client
          .from('checkpoints')
          .select()
          .eq('activity_id', activityId)
          .order('order_index', ascending: true)
          .limit(20); // Add pagination limit

      final checkpoints = (response as List).cast<Map<String, dynamic>>();
      await _cache.cacheCheckpoints(activityId, checkpoints);

      return Success(checkpoints);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to load checkpoints',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading checkpoints',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get checkpoint count for an activity
  Future<Result<int>> getCheckpointCount(String activityId) async {
    try {
      // Validate input
      final idValidation = InputValidator.validateAndSanitizeText(
        activityId,
        fieldName: 'Activity ID',
        minLength: 1,
        maxLength: 50,
      );
      if (idValidation.isFailure) {
        return Failure(idValidation.error!);
      }

      final response = await _client
          .from('checkpoints')
          .select('id')
          .eq('activity_id', activityId);

      return Success((response as List).length);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to count checkpoints',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error counting checkpoints',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }
}
