import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/error_handler.dart';

class GameMapService {
  final SupabaseClient _client;

  GameMapService(this._client);

  Future<Map<String, dynamic>> getActivity(String activityId) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('id', activityId)
          .single();
      return response;
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'loading activity data', stackTrace: st);
      throw Exception(appError.message);
    }
  }

  RealtimeChannel subscribeToActivityStatus({
    required String activityId,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    return _client
        .channel('game_activity_status_$activityId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'activities',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: activityId,
          ),
          callback: callback,
        )
        .subscribe();
  }

  RealtimeChannel subscribeToAnnouncements({
    required String activityId,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    return _client
        .channel('announcements_$activityId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'announcements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: activityId,
          ),
          callback: callback,
        )
        .subscribe();
  }

  Future<Map<String, dynamic>> getTeamInfo(String teamId) async {
    try {
      final response = await _client
          .from('teams')
          .select('team_name, emoji')
          .eq('id', teamId)
          .single();
      return response;
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'loading team info', stackTrace: st);
      throw Exception(appError.message);
    }
  }

  Future<List<Map<String, dynamic>>> getCheckpoints(String activityId) async {
    try {
      final response = await _client
          .from('checkpoints')
          .select()
          .eq('activity_id', activityId)
          .order('sequence_order', ascending: true);

      return List<Map<String, dynamic>>.from(
        (response as List).cast<Map<String, dynamic>>(),
      );
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'loading checkpoints', stackTrace: st);
      throw Exception(appError.message);
    }
  }

  Future<Set<String>> getArrivedCheckpointIds(String teamId) async {
    try {
      final response = await _client
          .from('team_progress')
          .select('checkpoint_id')
          .eq('team_id', teamId);

      return Set<String>.from(
        (response as List).map((r) => r['checkpoint_id'] as String),
      );
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'loading checkpoint progress', stackTrace: st);
      throw Exception(appError.message);
    }
  }

  Future<void> updateParticipantLocation({
    required String participantId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _client.from('participants').update({
        'current_latitude': latitude,
        'current_longitude': longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', participantId);
    } catch (e, st) {
      // Location updates are best-effort — log but don't throw to avoid disrupting game flow
      final appError = ErrorHandler.handle(e, context: 'updating location', stackTrace: st);
      debugPrint('GameMapService.updateParticipantLocation: ${appError.message}');
    }
  }

  Future<Map<String, dynamic>?> getTeamCheckpointProgress({
    required String teamId,
    required String checkpointId,
  }) async {
    try {
      final existing = await _client
          .from('team_progress')
          .select()
          .eq('team_id', teamId)
          .eq('checkpoint_id', checkpointId)
          .maybeSingle();

      return existing;
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'loading team progress', stackTrace: st);
      throw Exception(appError.message);
    }
  }

  Future<Map<String, dynamic>?> getParticipantCheckpointArrival({
    required String participantId,
    required String checkpointId,
  }) async {
    try {
      final existing = await _client
          .from('checkpoint_arrivals')
          .select()
          .eq('checkpoint_id', checkpointId)
          .eq('participant_id', participantId)
          .maybeSingle();

      return existing;
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'checking arrival status', stackTrace: st);
      throw Exception(appError.message);
    }
  }

  Future<void> insertCheckpointArrival({
    required String checkpointId,
    required String participantId,
    required String teamId,
    required String activityId,
    double? latitude,
    double? longitude,
    double? distanceFromCheckpoint,
  }) async {
    try {
      await _client.from('checkpoint_arrivals').insert({
        'checkpoint_id': checkpointId,
        'participant_id': participantId,
        'team_id': teamId,
        'activity_id': activityId,
        'latitude': latitude,
        'longitude': longitude,
        'distance_from_checkpoint': distanceFromCheckpoint,
        'arrived_at': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'recording checkpoint arrival', stackTrace: st);
      throw Exception(appError.message);
    }
  }

  Future<Map<String, dynamic>?> checkAllTeamMembersPresent({
    required String checkpointId,
    required String teamId,
  }) async {
    try {
      final result = await _client.rpc(
        'check_all_team_members_present',
        params: {
          'p_checkpoint_id': checkpointId,
          'p_team_id': teamId,
        },
      ).select();

      if (result.isEmpty) return null;
      return result.first;
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'checking team presence', stackTrace: st);
      throw Exception(appError.message);
    }
  }

  Future<void> completeCheckpointAndAwardPoints({
    required String teamId,
    required String checkpointId,
    required int arrivalPoints,
  }) async {
    try {
      await _client.rpc(
        'complete_checkpoint_and_award_points',
        params: {
          'p_team_id': teamId,
          'p_checkpoint_id': checkpointId,
          'p_arrival_points': arrivalPoints,
        },
      );
    } catch (e, st) {
      final appError = ErrorHandler.handle(e, context: 'completing checkpoint', stackTrace: st);
      throw Exception(appError.message);
    }
  }
}
