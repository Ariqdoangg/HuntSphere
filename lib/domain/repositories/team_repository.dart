import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/features/shared/models/team_model.dart';

/// Abstract repository for team data operations
abstract class TeamRepository {
  /// Get all teams for an activity
  Future<Result<List<TeamModel>>> getTeams(String activityId);
  
  /// Get a single team by ID
  Future<Result<TeamModel>> getTeam(String teamId);
  
  /// Get leaderboard data for an activity
  Future<Result<List<Map<String, dynamic>>>> getLeaderboard(String activityId);
  
  /// Create a new team
  Future<Result<TeamModel>> createTeam({
    required String activityId,
    required String teamName,
    String? color,
    String? emoji,
  });
  
  /// Update team points using atomic increment
  Future<Result<TeamModel>> updateTeamPoints({
    required String teamId,
    required int pointsToAdd,
  });
  
  /// Increment checkpoints completed using atomic increment
  Future<Result<TeamModel>> incrementCheckpointsCompleted(String teamId);
  
  /// Mark team as finished
  Future<Result<TeamModel>> markTeamFinished(String teamId);
  
  /// Get participants for a team
  Future<Result<List<Map<String, dynamic>>>> getTeamParticipants(String teamId);
  
  /// Get team count for an activity
  Future<Result<int>> getTeamCount(String activityId);
  
  /// Delete a team
  Future<Result<void>> deleteTeam(String teamId);
}
