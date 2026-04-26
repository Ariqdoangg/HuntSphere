import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/core/utils/retry_policy.dart';
import 'package:huntsphere/data/repositories/supabase_activity_repository.dart';
import 'package:huntsphere/data/repositories/supabase_team_repository.dart';
import 'package:huntsphere/domain/repositories/activity_repository.dart';
import 'package:huntsphere/domain/repositories/team_repository.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/services/cache_service.dart';
import 'package:huntsphere/services/connectivity_service.dart';
import 'package:huntsphere/services/refactored/activity_service.dart';
import 'package:huntsphere/services/refactored/team_service.dart';

// ============================================================================
// CORE INFRASTRUCTURE PROVIDERS
// ============================================================================

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Connectivity service provider (singleton)
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Cache service provider (singleton)
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Connectivity state provider
final connectivityStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Is online provider (synchronous access)
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityStateProvider);
  return connectivity.whenOrNull(data: (isOnline) => isOnline) ??
      ref.read(connectivityServiceProvider).isOnline;
});

/// Circuit breaker provider for resilient API calls
final circuitBreakerProvider = Provider<CircuitBreaker>((ref) {
  return CircuitBreaker(
    failureThreshold: 5,
    resetTimeout: const Duration(seconds: 30),
  );
});

/// Retry policy provider
final retryPolicyProvider = Provider<RetryPolicy>((ref) {
  return const RetryPolicy(
    maxRetries: 3,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
  );
});

/// Activity repository provider
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseActivityRepository(client);
});

/// Team repository provider
final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseTeamRepository(client);
});

// ============================================================================
// SERVICE PROVIDERS (Refactored with Repository Pattern)
// ============================================================================

/// Team service provider (using new repository pattern)
final teamServiceProvider = Provider<TeamService>((ref) {
  final repository = ref.watch(teamRepositoryProvider);
  final cache = ref.watch(cacheServiceProvider);
  return TeamService(repository, cache);
});

/// Activity service provider (using new repository pattern)
final activityServiceProvider = Provider<ActivityService>((ref) {
  final repository = ref.watch(activityRepositoryProvider);
  final cache = ref.watch(cacheServiceProvider);
  return ActivityService(repository, cache);
});

// ============================================================================
// FEATURE-SCOPED PROVIDERS
// ============================================================================

/// Game feature state
class GameState {
  final List<ActivityModel> activities;
  final ActivityModel? currentActivity;
  final bool isLoading;
  final String? error;
  final bool isOffline;

  const GameState({
    this.activities = const [],
    this.currentActivity,
    this.isLoading = false,
    this.error,
    this.isOffline = false,
  });

  GameState copyWith({
    List<ActivityModel>? activities,
    ActivityModel? currentActivity,
    bool? isLoading,
    String? error,
    bool? isOffline,
    bool clearCurrentActivity = false,
  }) {
    return GameState(
      activities: activities ?? this.activities,
      currentActivity: clearCurrentActivity ? null : (currentActivity ?? this.currentActivity),
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// Consolidated game feature notifier with TeamService integration
class GameFeatureNotifier extends StateNotifier<GameState> {
  final ActivityService _activityService;
  final TeamService _teamService;
  final Ref _ref;

  GameFeatureNotifier(this._activityService, this._teamService, this._ref)
      : super(const GameState()) {
    // Listen to connectivity changes
    _ref.listen(connectivityStateProvider, (previous, next) {
      next.whenOrNull(
        data: (isOnline) => state = state.copyWith(isOffline: !isOnline),
      );
    });
  }

  /// Load all activities for current user
  Future<void> loadActivities({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    final user = _ref.read(currentUserProvider);
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Not authenticated',
      );
      return;
    }

    final result = await _activityService.getActivities(
      forceRefresh: forceRefresh,
      userId: user.id,
    );

    result.when(
      success: (activities) {
        state = state.copyWith(
          activities: activities,
          isLoading: false,
        );
      },
      failure: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error.message,
        );
      },
    );
  }

  /// Create a new activity
  Future<Result<ActivityModel>> createActivity({
    required String name,
    required int durationMinutes,
    String? joinCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final user = _ref.read(currentUserProvider);
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Not authenticated',
      );
      return const Failure(AppError(
        message: 'Not authenticated',
        type: ErrorType.authentication,
      ));
    }

    final result = await _activityService.createActivity(
      name: name,
      durationMinutes: durationMinutes,
      userId: user.id,
      joinCode: joinCode,
    );

    result.when(
      success: (activity) {
        // Refresh the list
        loadActivities(forceRefresh: true);
      },
      failure: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error.message,
        );
      },
    );

    return result;
  }

  /// Set current activity
  void selectActivity(ActivityModel activity) {
    state = state.copyWith(currentActivity: activity);
  }

  /// Clear current activity
  void clearCurrentActivity() {
    state = state.copyWith(clearCurrentActivity: true);
  }

  /// Start an activity
  Future<Result<ActivityModel>> startActivity(String activityId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _activityService.startActivity(activityId);

    result.when(
      success: (activity) {
        // Update the activity in the list
        final updatedActivities = state.activities.map((a) {
          return a.id == activity.id ? activity : a;
        }).toList();
        
        state = state.copyWith(
          activities: updatedActivities,
          currentActivity: activity,
          isLoading: false,
        );
      },
      failure: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error.message,
        );
      },
    );

    return result;
  }

  /// Delete an activity
  Future<Result<void>> deleteActivity(String activityId) async {
    state = state.copyWith(isLoading: true, error: null);

    final user = _ref.read(currentUserProvider);
    
    final result = await _activityService.deleteActivity(
      activityId,
      userId: user?.id,
    );

    result.when(
      success: (_) {
        // Remove from list
        final updatedActivities = state.activities
            .where((a) => a.id != activityId)
            .toList();
        
        state = state.copyWith(
          activities: updatedActivities,
          isLoading: false,
          clearCurrentActivity: state.currentActivity?.id == activityId,
        );
      },
      failure: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error.message,
        );
      },
    );

    return result;
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Consolidated game feature provider
/// Single source of truth for game-related state including teams
final gameFeatureProvider = StateNotifierProvider<GameFeatureNotifier, GameState>((ref) {
  final activityService = ref.watch(activityServiceProvider);
  final teamService = ref.watch(teamServiceProvider);
  return GameFeatureNotifier(activityService, teamService, ref);
});

// ============================================================================
// AUTHENTICATION PROVIDERS
// ============================================================================

/// Current user stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (state) => state.session?.user,
  );
});
