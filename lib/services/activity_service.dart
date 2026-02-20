import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/error_handler.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/services/auth_service.dart';
import 'package:huntsphere/services/cache_service.dart';

/// Activity service for managing game activities
class ActivityService {
  final SupabaseClient _client;
  final CacheService _cache;

  ActivityService(this._client, this._cache);

  /// Get current user ID
  String? get _userId => _client.auth.currentUser?.id;

  /// Get all activities for the current facilitator
  Future<ServiceResult<List<ActivityModel>>> getActivities({
    bool forceRefresh = false,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) {
        return ServiceResult.failure(
          const AppError(
            message: 'Not authenticated',
            type: ErrorType.authentication,
          ),
        );
      }

      // Try cache first
      if (!forceRefresh) {
        final cached = _cache.getCachedActivities(userId);
        if (cached != null) {
          debugPrint('ActivityService: Using cached activities');
          return ServiceResult.success(
            cached.map((json) => ActivityModel.fromJson(json)).toList(),
          );
        }
      }

      final response = await _client
          .from('activities')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      final activities = (response as List)
          .map((json) => ActivityModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Update cache
      await _cache.cacheActivities(
        userId,
        response.cast<Map<String, dynamic>>(),
      );

      return ServiceResult.success(activities);
    } catch (e) {
      debugPrint('ActivityService.getActivities error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading activities'),
      );
    }
  }

  /// Get a single activity by ID
  Future<ServiceResult<ActivityModel>> getActivity(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    try {
      // Try cache first
      if (!forceRefresh) {
        final cached = _cache.getCachedActivity(activityId);
        if (cached != null) {
          return ServiceResult.success(ActivityModel.fromJson(cached));
        }
      }

      final response = await _client
          .from('activities')
          .select()
          .eq('id', activityId)
          .single();

      await _cache.cacheActivity(activityId, response);

      return ServiceResult.success(ActivityModel.fromJson(response));
    } catch (e) {
      debugPrint('ActivityService.getActivity error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading activity'),
      );
    }
  }

  /// Get activity by join code
  Future<ServiceResult<ActivityModel>> getActivityByJoinCode(String joinCode) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('join_code', joinCode.toUpperCase())
          .single();

      return ServiceResult.success(ActivityModel.fromJson(response));
    } catch (e) {
      debugPrint('ActivityService.getActivityByJoinCode error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'finding activity'),
      );
    }
  }

  /// Create a new activity
  Future<ServiceResult<ActivityModel>> createActivity({
    required String name,
    required int durationMinutes,
    String? joinCode,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) {
        return ServiceResult.failure(
          const AppError(
            message: 'Not authenticated',
            type: ErrorType.authentication,
          ),
        );
      }

      // Generate join code if not provided
      final code = joinCode ?? await _generateJoinCode();

      final data = {
        'name': name,
        'join_code': code,
        'total_duration_minutes': durationMinutes,
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

      return ServiceResult.success(ActivityModel.fromJson(response));
    } catch (e) {
      debugPrint('ActivityService.createActivity error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'creating activity'),
      );
    }
  }

  /// Update an activity
  Future<ServiceResult<ActivityModel>> updateActivity(ActivityModel activity) async {
    try {
      if (activity.id == null) {
        return ServiceResult.failure(
          const AppError(
            message: 'Activity ID is required',
            type: ErrorType.validation,
          ),
        );
      }

      final response = await _client
          .from('activities')
          .update(activity.toJson())
          .eq('id', activity.id!)
          .select()
          .single();

      // Invalidate caches
      await _cache.invalidateActivityCaches(activity.id!);
      if (_userId != null) {
        await _cache.clearActivitiesCache(_userId!);
      }

      return ServiceResult.success(ActivityModel.fromJson(response));
    } catch (e) {
      debugPrint('ActivityService.updateActivity error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'updating activity'),
      );
    }
  }

  /// Delete an activity
  Future<ServiceResult<void>> deleteActivity(String activityId) async {
    try {
      await _client.from('activities').delete().eq('id', activityId);

      // Invalidate caches
      await _cache.invalidateActivityCaches(activityId);
      if (_userId != null) {
        await _cache.clearActivitiesCache(_userId!);
      }

      return ServiceResult.success(null);
    } catch (e) {
      debugPrint('ActivityService.deleteActivity error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'deleting activity'),
      );
    }
  }

  /// Start an activity
  Future<ServiceResult<ActivityModel>> startActivity(String activityId) async {
    try {
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

      return ServiceResult.success(ActivityModel.fromJson(response));
    } catch (e) {
      debugPrint('ActivityService.startActivity error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'starting activity'),
      );
    }
  }

  /// End an activity
  Future<ServiceResult<ActivityModel>> endActivity(String activityId) async {
    try {
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

      return ServiceResult.success(ActivityModel.fromJson(response));
    } catch (e) {
      debugPrint('ActivityService.endActivity error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'ending activity'),
      );
    }
  }

  /// Generate a unique join code using cryptographically secure random
  Future<String> _generateJoinCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    const maxAttempts = 100;
    int attempts = 0;

    while (attempts < maxAttempts) {
      attempts++;
      final code = List.generate(
        6,
        (index) => chars[random.nextInt(chars.length)],
      ).join();

      final existing = await _client
          .from('activities')
          .select('id')
          .eq('join_code', code)
          .maybeSingle();

      if (existing == null) return code;
    }

    throw Exception('Failed to generate unique join code after $maxAttempts attempts');
  }

  /// Get checkpoints for an activity
  Future<ServiceResult<List<Map<String, dynamic>>>> getCheckpoints(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh) {
        final cached = _cache.getCachedCheckpoints(activityId);
        if (cached != null) {
          return ServiceResult.success(cached);
        }
      }

      final response = await _client
          .from('checkpoints')
          .select()
          .eq('activity_id', activityId)
          .order('order_index', ascending: true);

      final checkpoints = (response as List).cast<Map<String, dynamic>>();
      await _cache.cacheCheckpoints(activityId, checkpoints);

      return ServiceResult.success(checkpoints);
    } catch (e) {
      debugPrint('ActivityService.getCheckpoints error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading checkpoints'),
      );
    }
  }

  /// Get checkpoint count for an activity
  Future<ServiceResult<int>> getCheckpointCount(String activityId) async {
    try {
      final response = await _client
          .from('checkpoints')
          .select('id')
          .eq('activity_id', activityId);

      return ServiceResult.success((response as List).length);
    } catch (e) {
      debugPrint('ActivityService.getCheckpointCount error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'counting checkpoints'),
      );
    }
  }
}
