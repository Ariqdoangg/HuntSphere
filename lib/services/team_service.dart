import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/error_handler.dart';
import 'package:huntsphere/features/shared/models/team_model.dart';
import 'package:huntsphere/services/auth_service.dart';
import 'package:huntsphere/services/cache_service.dart';

/// Team service for managing teams and leaderboard
class TeamService {
  final SupabaseClient _client;
  final CacheService _cache;

  TeamService(this._client, this._cache);

  /// Get all teams for an activity
  Future<ServiceResult<List<TeamModel>>> getTeams(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh) {
        final cached = _cache.getCachedTeams(activityId);
        if (cached != null) {
          return ServiceResult.success(
            cached.map((json) => TeamModel.fromJson(json)).toList(),
          );
        }
      }

      final response = await _client
          .from('teams')
          .select()
          .eq('activity_id', activityId)
          .order('total_points', ascending: false)
          .order('finished_at', ascending: true, nullsFirst: false);

      final teams = (response as List)
          .map((json) => TeamModel.fromJson(json as Map<String, dynamic>))
          .toList();

      await _cache.cacheTeams(activityId, response.cast<Map<String, dynamic>>());

      return ServiceResult.success(teams);
    } catch (e) {
      debugPrint('TeamService.getTeams error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading teams'),
      );
    }
  }

  /// Get a single team by ID
  Future<ServiceResult<TeamModel>> getTeam(String teamId) async {
    try {
      final response = await _client
          .from('teams')
          .select()
          .eq('id', teamId)
          .single();

      return ServiceResult.success(TeamModel.fromJson(response));
    } catch (e) {
      debugPrint('TeamService.getTeam error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading team'),
      );
    }
  }

  /// Get leaderboard for an activity (sorted by points, then by finish time)
  Future<ServiceResult<List<Map<String, dynamic>>>> getLeaderboard(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh) {
        final cached = _cache.getCachedLeaderboard(activityId);
        if (cached != null) {
          return ServiceResult.success(cached);
        }
      }

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

      final leaderboard = (response as List).cast<Map<String, dynamic>>();
      await _cache.cacheLeaderboard(activityId, leaderboard);

      return ServiceResult.success(leaderboard);
    } catch (e) {
      debugPrint('TeamService.getLeaderboard error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading leaderboard'),
      );
    }
  }

  /// Create a new team
  Future<ServiceResult<TeamModel>> createTeam({
    required String activityId,
    required String teamName,
    String? color,
    String? emoji,
  }) async {
    try {
      final data = {
        'activity_id': activityId,
        'team_name': teamName,
        'color': color,
        'emoji': emoji,
        'total_points': 0,
        'checkpoints_completed': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('teams')
          .insert(data)
          .select()
          .single();

      await _cache.invalidateActivityCaches(activityId);

      return ServiceResult.success(TeamModel.fromJson(response));
    } catch (e) {
      debugPrint('TeamService.createTeam error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'creating team'),
      );
    }
  }

  /// Update team points atomically using RPC to avoid race conditions
  Future<ServiceResult<TeamModel>> updateTeamPoints({
    required String teamId,
    required int pointsToAdd,
  }) async {
    try {
      // Use RPC for atomic increment to prevent race conditions
      await _client.rpc('increment_team_points', params: {
        'team_id_param': teamId,
        'points_to_add': pointsToAdd,
      });

      // Fetch updated team
      final response = await _client
          .from('teams')
          .select()
          .eq('id', teamId)
          .single();

      final activityId = response['activity_id'] as String;
      await _cache.invalidateActivityCaches(activityId);

      return ServiceResult.success(TeamModel.fromJson(response));
    } catch (e) {
      debugPrint('TeamService.updateTeamPoints error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'updating points'),
      );
    }
  }

  /// Increment checkpoints completed atomically using RPC
  Future<ServiceResult<TeamModel>> incrementCheckpointsCompleted(String teamId) async {
    try {
      // Use RPC for atomic increment to prevent race conditions
      await _client.rpc('increment_team_checkpoints', params: {
        'team_id_param': teamId,
      });

      // Fetch updated team
      final response = await _client
          .from('teams')
          .select()
          .eq('id', teamId)
          .single();

      final activityId = response['activity_id'] as String;
      await _cache.invalidateActivityCaches(activityId);

      return ServiceResult.success(TeamModel.fromJson(response));
    } catch (e) {
      debugPrint('TeamService.incrementCheckpointsCompleted error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'updating progress'),
      );
    }
  }

  /// Mark team as finished
  Future<ServiceResult<TeamModel>> markTeamFinished(String teamId) async {
    try {
      final current = await _client
          .from('teams')
          .select('activity_id')
          .eq('id', teamId)
          .single();

      final activityId = current['activity_id'] as String;

      final response = await _client
          .from('teams')
          .update({'finished_at': DateTime.now().toIso8601String()})
          .eq('id', teamId)
          .select()
          .single();

      await _cache.invalidateActivityCaches(activityId);

      return ServiceResult.success(TeamModel.fromJson(response));
    } catch (e) {
      debugPrint('TeamService.markTeamFinished error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'marking team as finished'),
      );
    }
  }

  /// Get participants for a team
  Future<ServiceResult<List<Map<String, dynamic>>>> getTeamParticipants(
    String teamId,
  ) async {
    try {
      final response = await _client
          .from('participants')
          .select()
          .eq('team_id', teamId)
          .order('created_at', ascending: true);

      return ServiceResult.success((response as List).cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('TeamService.getTeamParticipants error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading participants'),
      );
    }
  }

  /// Get team count for an activity
  Future<ServiceResult<int>> getTeamCount(String activityId) async {
    try {
      final response = await _client
          .from('teams')
          .select('id')
          .eq('activity_id', activityId);

      return ServiceResult.success((response as List).length);
    } catch (e) {
      debugPrint('TeamService.getTeamCount error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'counting teams'),
      );
    }
  }

  /// Delete a team
  Future<ServiceResult<void>> deleteTeam(String teamId) async {
    try {
      final team = await _client
          .from('teams')
          .select('activity_id')
          .eq('id', teamId)
          .single();

      final activityId = team['activity_id'] as String;

      await _client.from('teams').delete().eq('id', teamId);

      await _cache.invalidateActivityCaches(activityId);

      return ServiceResult.success(null);
    } catch (e) {
      debugPrint('TeamService.deleteTeam error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'deleting team'),
      );
    }
  }
}
