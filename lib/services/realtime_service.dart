import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Event types for real-time updates
enum RealtimeEventType { insert, update, delete }

/// Real-time event wrapper
class RealtimeEvent<T> {
  final RealtimeEventType type;
  final T data;
  final T? oldData;

  RealtimeEvent({
    required this.type,
    required this.data,
    this.oldData,
  });
}

/// Leaderboard entry for real-time updates
class LeaderboardEntry {
  final String id;
  final String teamName;
  final String? emoji;
  final String? color;
  final int totalPoints;
  final int checkpointsCompleted;
  final DateTime? finishedAt;

  LeaderboardEntry({
    required this.id,
    required this.teamName,
    this.emoji,
    this.color,
    required this.totalPoints,
    required this.checkpointsCompleted,
    this.finishedAt,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'],
      teamName: json['team_name'] ?? 'Team',
      emoji: json['emoji'],
      color: json['color'],
      totalPoints: json['total_points'] ?? 0,
      checkpointsCompleted: json['checkpoints_completed'] ?? 0,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'])
          : null,
    );
  }
}

/// Real-time service for Supabase subscriptions
class RealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController<dynamic>> _controllers = {};
  bool _isDisposed = false;

  RealtimeService(this._client);

  /// Subscribe to leaderboard updates for an activity
  Stream<List<LeaderboardEntry>> subscribeToLeaderboard(String activityId) {
    if (_isDisposed) throw StateError('RealtimeService has been disposed');
    final channelName = 'leaderboard_$activityId';

    // Return existing stream if already subscribed
    if (_controllers.containsKey(channelName)) {
      return (_controllers[channelName] as StreamController<List<LeaderboardEntry>>).stream;
    }

    final controller = StreamController<List<LeaderboardEntry>>.broadcast(
      onCancel: () => _unsubscribe(channelName),
    );
    _controllers[channelName] = controller;

    // Create channel
    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'teams',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: activityId,
          ),
          callback: (payload) {
            debugPrint('RealtimeService: Teams update received');
            _fetchAndEmitLeaderboard(activityId, controller);
          },
        )
        .subscribe((status, error) {
          debugPrint('RealtimeService: Leaderboard subscription status: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Initial fetch
            _fetchAndEmitLeaderboard(activityId, controller);
          }
          if (error != null) {
            debugPrint('RealtimeService: Subscription error: $error');
          }
        });

    _channels[channelName] = channel;

    return controller.stream;
  }

  /// Fetch and emit leaderboard data
  Future<void> _fetchAndEmitLeaderboard(
    String activityId,
    StreamController<List<LeaderboardEntry>> controller,
  ) async {
    try {
      final response = await _client
          .from('teams')
          .select('''
            id,
            team_name,
            emoji,
            color,
            total_points,
            checkpoints_completed,
            finished_at
          ''')
          .eq('activity_id', activityId)
          .order('total_points', ascending: false)
          .order('finished_at', ascending: true, nullsFirst: false);

      final entries = (response as List)
          .map((json) => LeaderboardEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      if (!controller.isClosed) {
        controller.add(entries);
      }
    } catch (e) {
      debugPrint('RealtimeService: Error fetching leaderboard: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  /// Subscribe to activity status changes
  Stream<Map<String, dynamic>> subscribeToActivityStatus(String activityId) {
    if (_isDisposed) throw StateError('RealtimeService has been disposed');
    final channelName = 'activity_$activityId';

    if (_controllers.containsKey(channelName)) {
      return (_controllers[channelName] as StreamController<Map<String, dynamic>>).stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () => _unsubscribe(channelName),
    );
    _controllers[channelName] = controller;

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'activities',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: activityId,
          ),
          callback: (payload) {
            debugPrint('RealtimeService: Activity update received');
            if (!controller.isClosed && payload.newRecord.isNotEmpty) {
              controller.add(payload.newRecord);
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('RealtimeService: Activity subscription status: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            _fetchAndEmitActivity(activityId, controller);
          }
        });

    _channels[channelName] = channel;

    return controller.stream;
  }

  /// Fetch and emit activity data
  Future<void> _fetchAndEmitActivity(
    String activityId,
    StreamController<Map<String, dynamic>> controller,
  ) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('id', activityId)
          .single();

      if (!controller.isClosed) {
        controller.add(response);
      }
    } catch (e) {
      debugPrint('RealtimeService: Error fetching activity: $e');
    }
  }

  /// Subscribe to team changes for an activity (for lobby)
  Stream<List<Map<String, dynamic>>> subscribeToTeams(String activityId) {
    if (_isDisposed) throw StateError('RealtimeService has been disposed');
    final channelName = 'teams_$activityId';

    if (_controllers.containsKey(channelName)) {
      return (_controllers[channelName] as StreamController<List<Map<String, dynamic>>>).stream;
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onCancel: () => _unsubscribe(channelName),
    );
    _controllers[channelName] = controller;

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'teams',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: activityId,
          ),
          callback: (payload) {
            debugPrint('RealtimeService: Teams change received');
            _fetchAndEmitTeams(activityId, controller);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _fetchAndEmitTeams(activityId, controller);
          }
        });

    _channels[channelName] = channel;

    return controller.stream;
  }

  /// Fetch and emit teams data
  Future<void> _fetchAndEmitTeams(
    String activityId,
    StreamController<List<Map<String, dynamic>>> controller,
  ) async {
    try {
      final response = await _client
          .from('teams')
          .select('*, participants(*)')
          .eq('activity_id', activityId)
          .order('created_at', ascending: true);

      if (!controller.isClosed) {
        controller.add((response as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('RealtimeService: Error fetching teams: $e');
    }
  }

  /// Subscribe to participants joining a team
  Stream<List<Map<String, dynamic>>> subscribeToParticipants(String activityId) {
    if (_isDisposed) throw StateError('RealtimeService has been disposed');
    final channelName = 'participants_$activityId';

    if (_controllers.containsKey(channelName)) {
      return (_controllers[channelName] as StreamController<List<Map<String, dynamic>>>).stream;
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onCancel: () => _unsubscribe(channelName),
    );
    _controllers[channelName] = controller;

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: activityId,
          ),
          callback: (payload) {
            debugPrint('RealtimeService: Participants change received');
            _fetchAndEmitParticipants(activityId, controller);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _fetchAndEmitParticipants(activityId, controller);
          }
        });

    _channels[channelName] = channel;

    return controller.stream;
  }

  /// Fetch and emit participants data
  Future<void> _fetchAndEmitParticipants(
    String activityId,
    StreamController<List<Map<String, dynamic>>> controller,
  ) async {
    try {
      final response = await _client
          .from('participants')
          .select()
          .eq('activity_id', activityId)
          .order('created_at', ascending: true);

      if (!controller.isClosed) {
        controller.add((response as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('RealtimeService: Error fetching participants: $e');
    }
  }

  /// Unsubscribe from a channel
  void _unsubscribe(String channelName) {
    debugPrint('RealtimeService: Unsubscribing from $channelName');

    final channel = _channels.remove(channelName);
    if (channel != null) {
      _client.removeChannel(channel);
    }

    final controller = _controllers.remove(channelName);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  /// Unsubscribe from a specific leaderboard
  void unsubscribeFromLeaderboard(String activityId) {
    _unsubscribe('leaderboard_$activityId');
  }

  /// Unsubscribe from activity status
  void unsubscribeFromActivityStatus(String activityId) {
    _unsubscribe('activity_$activityId');
  }

  /// Unsubscribe from teams
  void unsubscribeFromTeams(String activityId) {
    _unsubscribe('teams_$activityId');
  }

  /// Unsubscribe from participants
  void unsubscribeFromParticipants(String activityId) {
    _unsubscribe('participants_$activityId');
  }

  /// Unsubscribe all channels for a specific activity
  void unsubscribeFromActivity(String activityId) {
    final prefixes = [
      'leaderboard_$activityId',
      'activity_$activityId',
      'teams_$activityId',
      'participants_$activityId',
    ];
    for (final channelName in prefixes) {
      _unsubscribe(channelName);
    }
  }

  /// Dispose all subscriptions
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('RealtimeService: Disposing all subscriptions');

    for (final channel in _channels.values) {
      _client.removeChannel(channel);
    }
    _channels.clear();

    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
  }
}
