import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/error_handler.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';
import 'package:huntsphere/services/auth_service.dart';

class LobbyService {
  final SupabaseClient _client;

  LobbyService(this._client);

  Future<ServiceResult<List<ParticipantModel>>> getParticipantsForActivity(
    String activityId,
  ) async {
    try {
      final response = await _client
          .from('participants')
          .select()
          .eq('activity_id', activityId)
          .order('joined_at', ascending: true);

      final participants = (response as List)
          .map(
            (json) => ParticipantModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();

      return ServiceResult.success(participants);
    } catch (e, st) {
      debugPrint('LobbyService.getParticipantsForActivity error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'loading participants', stackTrace: st),
      );
    }
  }

  Future<ServiceResult<void>> startActivityAndFormTeams({
    required ActivityModel activity,
    required List<ParticipantModel> participants,
  }) async {
    if (participants.length < 3) {
      return ServiceResult.failure(
        const AppError(
          message: 'Need at least 3 participants to start the activity.',
          type: ErrorType.validation,
        ),
      );
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _client
          .from('activities')
          .update({
            'status': 'active',
            'started_at': now,
            'game_started_at': now,
          })
          .eq('id', activity.id!);

      final participantIds = participants.map((p) => p.id!).toList();
      participantIds.shuffle();

      final totalParticipants = participantIds.length;
      final teamCount = _calculateTeamCount(totalParticipants);

      int participantIndex = 0;

      for (int i = 0; i < teamCount; i++) {
        final remainingParticipants = totalParticipants - participantIndex;
        final remainingTeams = teamCount - i;
        final teamSize = (remainingParticipants / remainingTeams).ceil();

        final teamResult = await _client
            .from('teams')
            .insert({
              'activity_id': activity.id,
              'team_number': i + 1,
              'team_name': 'Team ${i + 1}',
              'total_points': 0,
            })
            .select()
            .single();

        final teamId = teamResult['id'];

        for (int j = 0;
            j < teamSize && participantIndex < totalParticipants;
            j++) {
          await _client
              .from('participants')
              .update({'team_id': teamId})
              .eq('id', participantIds[participantIndex]);
          participantIndex++;
        }
      }

      return ServiceResult.success(null);
    } catch (e, st) {
      debugPrint('LobbyService.startActivityAndFormTeams error: $e');
      return ServiceResult.failure(
        ErrorHandler.handle(e, context: 'starting activity', stackTrace: st),
      );
    }
  }

  int _calculateTeamCount(int totalParticipants) {
    if (totalParticipants == 3) return 1;
    if (totalParticipants <= 5) return 2;
    if (totalParticipants <= 8) return 2;
    if (totalParticipants <= 12) return 3;
    if (totalParticipants <= 16) return 4;

    final count = (totalParticipants / 4).round();
    if (totalParticipants / count < 3) {
      return (totalParticipants / 3).ceil();
    }
    return count;
  }
}
