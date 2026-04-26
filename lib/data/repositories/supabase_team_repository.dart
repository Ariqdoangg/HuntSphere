import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/domain/repositories/team_repository.dart';
import 'package:huntsphere/features/shared/models/team_model.dart';

/// Supabase implementation of TeamRepository
class SupabaseTeamRepository implements TeamRepository {
  final SupabaseClient _client;
  
  SupabaseTeamRepository(this._client);

  @override
  Future<Result<List<TeamModel>>> getTeams(String activityId) async {
    try {
      final response = await _client
          .from('teams')
          .select()
          .eq('activity_id', activityId)
          .order('total_points', ascending: false)
          .order('finished_at', ascending: true, nullsFirst: false);
      
      final teams = (response as List)
          .map((json) => TeamModel.fromJson(json))
          .toList();
      
      return Success(teams);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to load teams',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading teams',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<TeamModel>> getTeam(String teamId) async {
    try {
      final response = await _client
          .from('teams')
          .select()
          .eq('id', teamId)
          .single();
      
      return Success(TeamModel.fromJson(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return Failure(AppError(
          message: 'Team not found',
          type: ErrorType.notFound,
        ));
      }
      return Failure(AppError(
        message: 'Failed to load team',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading team',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getLeaderboard(String activityId) async {
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
      
      final leaderboard = (response as List).cast<Map<String, dynamic>>();
      return Success(leaderboard);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to load leaderboard',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading leaderboard',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<TeamModel>> createTeam({
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

      return Success(TeamModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to create team',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error creating team',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<TeamModel>> updateTeamPoints({
    required String teamId,
    required int pointsToAdd,
  }) async {
    try {
      await _client.rpc('increment_team_points', params: {
        'team_id_param': teamId,
        'points_to_add': pointsToAdd,
      });

      final response = await _client
          .from('teams')
          .select()
          .eq('id', teamId)
          .single();

      return Success(TeamModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to update team points',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error updating points',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<TeamModel>> incrementCheckpointsCompleted(String teamId) async {
    try {
      await _client.rpc('increment_team_checkpoints', params: {
        'team_id_param': teamId,
      });

      final response = await _client
          .from('teams')
          .select()
          .eq('id', teamId)
          .single();

      return Success(TeamModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to update checkpoints',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error updating checkpoints',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<TeamModel>> markTeamFinished(String teamId) async {
    try {
      final response = await _client
          .from('teams')
          .update({'finished_at': DateTime.now().toIso8601String()})
          .eq('id', teamId)
          .select()
          .single();

      return Success(TeamModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to mark team as finished',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error marking team as finished',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getTeamParticipants(String teamId) async {
    try {
      final response = await _client
          .from('participants')
          .select()
          .eq('team_id', teamId)
          .order('created_at', ascending: true);

      return Success((response as List).cast<Map<String, dynamic>>());
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to load team participants',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading participants',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<int>> getTeamCount(String activityId) async {
    try {
      final response = await _client
          .from('teams')
          .select('id')
          .eq('activity_id', activityId);

      return Success((response as List).length);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to get team count',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error getting team count',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> deleteTeam(String teamId) async {
    try {
      await _client.from('teams').delete().eq('id', teamId);
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to delete team',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error deleting team',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }
}
