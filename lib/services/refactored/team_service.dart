import 'package:flutter/foundation.dart';
import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/domain/repositories/team_repository.dart';
import 'package:huntsphere/features/shared/models/team_model.dart';
import 'package:huntsphere/services/cache_service.dart';

/// Refactored Team service focused on business logic with caching
class TeamService {
  final TeamRepository _repository;
  final CacheService _cache;

  TeamService(this._repository, this._cache);

  /// Get all teams for an activity with caching
  Future<Result<List<TeamModel>>> getTeams(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    // Try cache first
    if (!forceRefresh) {
      final cached = _cache.getCachedTeams(activityId);
      if (cached != null) {
        debugPrint('TeamService: Using cached teams');
        final teams = cached.map((json) => TeamModel.fromJson(json)).toList();
        return Success(teams);
      }
    }

    // Fetch from repository
    final result = await _repository.getTeams(activityId);

    // Update cache on success
    result.onSuccess((teams) async {
      await _cache.cacheTeams(
        activityId,
        teams.map((t) => t.toJson()).toList(),
      );
    });

    return result;
  }

  /// Get a single team (always fresh, no cache)
  Future<Result<TeamModel>> getTeam(String teamId) async {
    return await _repository.getTeam(teamId);
  }

  /// Get leaderboard for an activity with caching
  Future<Result<List<Map<String, dynamic>>>> getLeaderboard(
    String activityId, {
    bool forceRefresh = false,
  }) async {
    // Try cache first
    if (!forceRefresh) {
      final cached = _cache.getCachedLeaderboard(activityId);
      if (cached != null) {
        return Success(cached);
      }
    }

    // Fetch from repository
    final result = await _repository.getLeaderboard(activityId);

    // Update cache on success
    result.onSuccess((leaderboard) async {
      await _cache.cacheLeaderboard(activityId, leaderboard);
    });

    return result;
  }

  /// Create a new team
  Future<Result<TeamModel>> createTeam({
    required String activityId,
    required String teamName,
    String? color,
    String? emoji,
  }) async {
    final result = await _repository.createTeam(
      activityId: activityId,
      teamName: teamName,
      color: color,
      emoji: emoji,
    );

    // Invalidate cache on success
    result.onSuccess((_) async {
      await _cache.invalidateActivityCaches(activityId);
    });

    return result;
  }

  /// Update team points (uses atomic increment via repository)
  Future<Result<TeamModel>> updateTeamPoints({
    required String teamId,
    required int pointsToAdd,
  }) async {
    final result = await _repository.updateTeamPoints(
      teamId: teamId,
      pointsToAdd: pointsToAdd,
    );

    // Invalidate cache on success
    result.onSuccess((team) async {
      if (team.activityId != null) {
        await _cache.invalidateActivityCaches(team.activityId!);
      }
    });

    return result;
  }

  /// Increment checkpoints completed
  Future<Result<TeamModel>> incrementCheckpointsCompleted(String teamId) async {
    final result = await _repository.incrementCheckpointsCompleted(teamId);

    // Invalidate cache on success
    result.onSuccess((team) async {
      if (team.activityId != null) {
        await _cache.invalidateActivityCaches(team.activityId!);
      }
    });

    return result;
  }

  /// Mark team as finished
  Future<Result<TeamModel>> markTeamFinished(String teamId) async {
    final result = await _repository.markTeamFinished(teamId);

    // Invalidate cache on success
    result.onSuccess((team) async {
      if (team.activityId != null) {
        await _cache.invalidateActivityCaches(team.activityId!);
      }
    });

    return result;
  }

  /// Get participants for a team
  Future<Result<List<Map<String, dynamic>>>> getTeamParticipants(String teamId) async {
    return await _repository.getTeamParticipants(teamId);
  }

  /// Get team count for an activity
  Future<Result<int>> getTeamCount(String activityId) async {
    return await _repository.getTeamCount(activityId);
  }

  /// Delete a team
  Future<Result<void>> deleteTeam(String teamId) async {
    // Get activity ID before deleting
    final teamResult = await _repository.getTeam(teamId);
    String? activityId;
    
    teamResult.onSuccess((team) {
      activityId = team.activityId;
    });

    final result = await _repository.deleteTeam(teamId);

    // Invalidate cache on success
    result.onSuccess((_) async {
      if (activityId != null) {
        await _cache.invalidateActivityCaches(activityId!);
      }
    });

    return result;
  }
}
