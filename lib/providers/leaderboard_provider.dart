import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huntsphere/core/di/service_locator.dart';
import 'package:huntsphere/services/realtime_service.dart';
import 'package:huntsphere/services/team_service.dart';

/// State class for leaderboard
class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final int totalCheckpoints;
  final bool isLoading;
  final bool isLive;
  final String? error;

  const LeaderboardState({
    this.entries = const [],
    this.totalCheckpoints = 0,
    this.isLoading = false,
    this.isLive = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    int? totalCheckpoints,
    bool? isLoading,
    bool? isLive,
    String? error,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      totalCheckpoints: totalCheckpoints ?? this.totalCheckpoints,
      isLoading: isLoading ?? this.isLoading,
      isLive: isLive ?? this.isLive,
      error: error,
    );
  }
}

/// Leaderboard state notifier with real-time updates
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final RealtimeService _realtimeService;
  final TeamService _teamService;
  final String activityId;

  StreamSubscription<List<LeaderboardEntry>>? _subscription;

  LeaderboardNotifier(
    this._realtimeService,
    this._teamService,
    this.activityId,
  ) : super(const LeaderboardState(isLoading: true)) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Load checkpoint count
    await _loadCheckpointCount();

    // Subscribe to real-time updates
    _subscribeToLeaderboard();
  }

  Future<void> _loadCheckpointCount() async {
    try {
      // Using team service to get activity info
      final result = await _teamService.getTeams(activityId);
      if (result.isSuccess && result.data!.isNotEmpty) {
        // We'll get checkpoint count from the activity service
        // For now, just continue with subscription
      }
    } catch (e) {
      // Ignore errors for checkpoint count
    }
  }

  void _subscribeToLeaderboard() {
    _subscription = _realtimeService.subscribeToLeaderboard(activityId).listen(
      (entries) {
        state = state.copyWith(
          entries: entries,
          isLoading: false,
          isLive: true,
          error: null,
        );
      },
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          isLive: false,
          error: 'Failed to load leaderboard',
        );
      },
    );
  }

  /// Update checkpoint count
  void setTotalCheckpoints(int count) {
    state = state.copyWith(totalCheckpoints: count);
  }

  /// Force refresh
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);

    final result = await _teamService.getLeaderboard(activityId, forceRefresh: true);

    result.whenSuccess((data) {
      state = state.copyWith(
        entries: data.map((json) => LeaderboardEntry.fromJson(json)).toList(),
        isLoading: false,
      );
    });

    result.whenFailure((error) {
      state = state.copyWith(
        isLoading: false,
        error: error.message,
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _realtimeService.unsubscribeFromLeaderboard(activityId);
    super.dispose();
  }
}

/// Leaderboard provider family (per activity)
final leaderboardProvider = StateNotifierProvider.autoDispose
    .family<LeaderboardNotifier, LeaderboardState, String>((ref, activityId) {
  final realtimeService = ref.watch(realtimeServiceProvider);
  final teamService = ref.watch(teamServiceProvider);

  return LeaderboardNotifier(realtimeService, teamService, activityId);
});

/// Total checkpoints provider for an activity
final totalCheckpointsProvider =
    FutureProvider.family<int, String>((ref, activityId) async {
  final activityService = ref.watch(activityServiceProvider);
  final result = await activityService.getCheckpointCount(activityId);
  return result.data ?? 0;
});

/// Stream provider for real-time leaderboard (alternative approach)
final leaderboardStreamProvider = StreamProvider.autoDispose
    .family<List<LeaderboardEntry>, String>((ref, activityId) {
  final realtimeService = ref.watch(realtimeServiceProvider);
  return realtimeService.subscribeToLeaderboard(activityId);
});

/// Teams state for lobby screen
class TeamsState {
  final List<Map<String, dynamic>> teams;
  final bool isLoading;
  final bool isLive;
  final String? error;

  const TeamsState({
    this.teams = const [],
    this.isLoading = false,
    this.isLive = false,
    this.error,
  });

  TeamsState copyWith({
    List<Map<String, dynamic>>? teams,
    bool? isLoading,
    bool? isLive,
    String? error,
  }) {
    return TeamsState(
      teams: teams ?? this.teams,
      isLoading: isLoading ?? this.isLoading,
      isLive: isLive ?? this.isLive,
      error: error,
    );
  }
}

/// Teams notifier with real-time updates
class TeamsNotifier extends StateNotifier<TeamsState> {
  final RealtimeService _realtimeService;
  final TeamService _teamService;
  final String activityId;

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  TeamsNotifier(
    this._realtimeService,
    this._teamService,
    this.activityId,
  ) : super(const TeamsState(isLoading: true)) {
    _subscribeToTeams();
  }

  void _subscribeToTeams() {
    _subscription = _realtimeService.subscribeToTeams(activityId).listen(
      (teams) {
        state = state.copyWith(
          teams: teams,
          isLoading: false,
          isLive: true,
          error: null,
        );
      },
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          isLive: false,
          error: 'Failed to load teams',
        );
      },
    );
  }

  /// Force refresh
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);

    final result = await _teamService.getTeams(activityId, forceRefresh: true);

    result.whenSuccess((teams) {
      state = state.copyWith(
        teams: teams.map((t) => t.toJson()).toList(),
        isLoading: false,
      );
    });

    result.whenFailure((error) {
      state = state.copyWith(
        isLoading: false,
        error: error.message,
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _realtimeService.unsubscribeFromTeams(activityId);
    super.dispose();
  }
}

/// Teams provider family (per activity)
final teamsProvider = StateNotifierProvider.autoDispose
    .family<TeamsNotifier, TeamsState, String>((ref, activityId) {
  final realtimeService = ref.watch(realtimeServiceProvider);
  final teamService = ref.watch(teamServiceProvider);

  return TeamsNotifier(realtimeService, teamService, activityId);
});
