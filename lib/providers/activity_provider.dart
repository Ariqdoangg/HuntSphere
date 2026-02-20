import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huntsphere/core/di/service_locator.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/services/activity_service.dart';
import 'package:huntsphere/services/auth_service.dart';

/// State class for activities list
class ActivitiesState {
  final List<ActivityModel> activities;
  final bool isLoading;
  final String? error;

  const ActivitiesState({
    this.activities = const [],
    this.isLoading = false,
    this.error,
  });

  ActivitiesState copyWith({
    List<ActivityModel>? activities,
    bool? isLoading,
    String? error,
  }) {
    return ActivitiesState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Activities state notifier
class ActivitiesNotifier extends StateNotifier<ActivitiesState> {
  final ActivityService _activityService;

  ActivitiesNotifier(this._activityService) : super(const ActivitiesState());

  /// Load activities
  Future<void> loadActivities({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _activityService.getActivities(forceRefresh: forceRefresh);

    result.whenSuccess((activities) {
      state = state.copyWith(activities: activities, isLoading: false);
    });

    result.whenFailure((error) {
      state = state.copyWith(isLoading: false, error: error.message);
    });
  }

  /// Create a new activity
  Future<ServiceResult<ActivityModel>> createActivity({
    required String name,
    required int durationMinutes,
  }) async {
    final result = await _activityService.createActivity(
      name: name,
      durationMinutes: durationMinutes,
    );

    if (result.isSuccess) {
      await loadActivities(forceRefresh: true);
    }

    return result;
  }

  /// Delete an activity
  Future<ServiceResult<void>> deleteActivity(String activityId) async {
    final result = await _activityService.deleteActivity(activityId);

    if (result.isSuccess) {
      state = state.copyWith(
        activities: state.activities.where((a) => a.id != activityId).toList(),
      );
    }

    return result;
  }

  /// Start an activity
  Future<ServiceResult<ActivityModel>> startActivity(String activityId) async {
    final result = await _activityService.startActivity(activityId);

    if (result.isSuccess) {
      state = state.copyWith(
        activities: state.activities.map((a) {
          if (a.id == activityId) {
            return result.data!;
          }
          return a;
        }).toList(),
      );
    }

    return result;
  }

  /// End an activity
  Future<ServiceResult<ActivityModel>> endActivity(String activityId) async {
    final result = await _activityService.endActivity(activityId);

    if (result.isSuccess) {
      state = state.copyWith(
        activities: state.activities.map((a) {
          if (a.id == activityId) {
            return result.data!;
          }
          return a;
        }).toList(),
      );
    }

    return result;
  }

  /// Refresh activities
  Future<void> refresh() => loadActivities(forceRefresh: true);
}

/// Activities provider
final activitiesProvider =
    StateNotifierProvider<ActivitiesNotifier, ActivitiesState>((ref) {
  final activityService = ref.watch(activityServiceProvider);
  return ActivitiesNotifier(activityService);
});

/// Single activity state
class ActivityDetailState {
  final ActivityModel? activity;
  final List<Map<String, dynamic>> checkpoints;
  final int teamCount;
  final bool isLoading;
  final String? error;

  const ActivityDetailState({
    this.activity,
    this.checkpoints = const [],
    this.teamCount = 0,
    this.isLoading = false,
    this.error,
  });

  ActivityDetailState copyWith({
    ActivityModel? activity,
    List<Map<String, dynamic>>? checkpoints,
    int? teamCount,
    bool? isLoading,
    String? error,
  }) {
    return ActivityDetailState(
      activity: activity ?? this.activity,
      checkpoints: checkpoints ?? this.checkpoints,
      teamCount: teamCount ?? this.teamCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Single activity detail notifier
class ActivityDetailNotifier extends StateNotifier<ActivityDetailState> {
  final ActivityService _activityService;
  final String activityId;

  ActivityDetailNotifier(this._activityService, this.activityId)
      : super(const ActivityDetailState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);

    final activityResult = await _activityService.getActivity(activityId);
    final checkpointsResult = await _activityService.getCheckpoints(activityId);

    if (activityResult.isSuccess) {
      state = state.copyWith(
        activity: activityResult.data,
        checkpoints: checkpointsResult.data ?? [],
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: activityResult.error?.message,
      );
    }
  }

  Future<void> refresh() => _load();
}

/// Activity detail provider family
final activityDetailProvider = StateNotifierProvider.family<
    ActivityDetailNotifier, ActivityDetailState, String>((ref, activityId) {
  final activityService = ref.watch(activityServiceProvider);
  return ActivityDetailNotifier(activityService, activityId);
});

/// Activity by join code provider
final activityByJoinCodeProvider =
    FutureProvider.family<ActivityModel?, String>((ref, joinCode) async {
  final activityService = ref.watch(activityServiceProvider);
  final result = await activityService.getActivityByJoinCode(joinCode);
  return result.data;
});
