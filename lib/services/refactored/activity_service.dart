import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/domain/repositories/activity_repository.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/services/cache_service.dart';

/// Refactored Activity service focused on business logic
/// Data access delegated to ActivityRepository
class ActivityService {
  final ActivityRepository _repository;
  final CacheService _cache;

  ActivityService(this._repository, this._cache);

  /// Get all activities with caching strategy
  Future<Result<List<ActivityModel>>> getActivities({
    bool forceRefresh = false,
    String? userId,
  }) async {
    if (userId == null) {
      return const Failure(AppError(
        message: 'Not authenticated',
        type: ErrorType.authentication,
      ));
    }

    // Try cache first
    if (!forceRefresh) {
      final cached = _cache.getCachedActivities(userId);
      if (cached != null) {
        debugPrint('ActivityService: Using cached activities');
        final activities = cached.map((json) => ActivityModel.fromJson(json)).toList();
        return Success(activities);
      }
    }

    // Fetch from repository
    final result = await _repository.getActivities(userId);
    
    // Update cache on success
    result.onSuccess((activities) async {
      await _cache.cacheActivities(
        userId,
        activities.map((a) => a.toJson()).toList(),
      );
    });

    return result;
  }

  /// Get a single activity with caching
  Future<Result<ActivityModel>> getActivity(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    // Try cache first
    if (!forceRefresh) {
      final cached = _cache.getCachedActivity(activityId);
      if (cached != null) {
        return Success(ActivityModel.fromJson(cached));
      }
    }

    // Fetch from repository
    final result = await _repository.getActivity(activityId);
    
    // Update cache on success
    result.onSuccess((activity) async {
      await _cache.cacheActivity(activityId, activity.toJson());
    });

    return result;
  }

  /// Get activity by join code (bypasses cache, always fresh)
  Future<Result<ActivityModel>> getActivityByJoinCode(String joinCode) async {
    // Note: This would need a repository method
    // For now, keeping the business logic here
    // In a full refactor, this would be moved to repository
    return const Failure(AppError(
      message: 'Not implemented in repository pattern',
      type: ErrorType.unknown,
    ));
  }

  /// Create a new activity with generated join code
  Future<Result<ActivityModel>> createActivity({
    required String name,
    required int durationMinutes,
    required String userId,
    String? joinCode,
  }) async {
    // Generate join code if not provided
    final code = joinCode ?? _generateJoinCodeInternal();

    final activity = ActivityModel(
      name: name,
      joinCode: code,
      totalDurationMinutes: durationMinutes,
      status: 'setup',
      createdBy: userId,
      createdAt: DateTime.now(),
    );

    final result = await _repository.createActivity(activity);
    
    // Invalidate cache on success
    result.onSuccess((_) async {
      await _cache.clearActivitiesCache(userId);
    });

    return result;
  }

  /// Update an activity
  Future<Result<ActivityModel>> updateActivity(ActivityModel activity) async {
    if (activity.id == null) {
      return const Failure(AppError(
        message: 'Activity ID is required',
        type: ErrorType.validation,
      ));
    }

    final result = await _repository.updateActivity(activity);
    
    // Invalidate caches on success
    result.onSuccess((_) async {
      await _cache.invalidateActivityCaches(activity.id!);
    });

    return result;
  }

  /// Delete an activity
  Future<Result<void>> deleteActivity(String activityId, {String? userId}) async {
    final result = await _repository.deleteActivity(activityId);
    
    // Invalidate caches on success
    result.onSuccess((_) async {
      await _cache.invalidateActivityCaches(activityId);
      if (userId != null) {
        await _cache.clearActivitiesCache(userId);
      }
    });

    return result;
  }

  /// Start an activity
  Future<Result<ActivityModel>> startActivity(String activityId) async {
    // This is business logic - update status and timestamps
    final activityResult = await _repository.getActivity(activityId);
    
    if (activityResult.isFailure) {
      return activityResult;
    }
    
    final activity = activityResult.data!;
    final updatedActivity = activity.copyWith(
      status: 'active',
      startedAt: DateTime.now(),
    );
    
    final result = await _repository.updateActivity(updatedActivity);
    
    result.onSuccess((_) async {
      await _cache.invalidateActivityCaches(activityId);
    });
    
    return result;
  }

  /// End an activity
  Future<Result<ActivityModel>> endActivity(String activityId) async {
    final activityResult = await _repository.getActivity(activityId);
    
    if (activityResult.isFailure) {
      return activityResult;
    }
    
    final activity = activityResult.data!;
    final updatedActivity = activity.copyWith(
      status: 'completed',
      endedAt: DateTime.now(),
    );
    
    final result = await _repository.updateActivity(updatedActivity);
    
    result.onSuccess((_) async {
      await _cache.invalidateActivityCaches(activityId);
    });
    
    return result;
  }

  /// Get activities by status
  Future<Result<List<ActivityModel>>> getActivitiesByStatus(
    String userId,
    String status,
  ) async {
    return await _repository.getActivitiesByStatus(userId, status);
  }

  /// Generate a unique join code
  String _generateJoinCodeInternal() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
