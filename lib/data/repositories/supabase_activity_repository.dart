import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/domain/repositories/activity_repository.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';

/// Supabase implementation of ActivityRepository
/// Handles all Supabase-specific data operations
class SupabaseActivityRepository implements ActivityRepository {
  final SupabaseClient _client;
  
  SupabaseActivityRepository(this._client);

  @override
  Future<Result<List<ActivityModel>>> getActivities(String userId) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);
      
      final activities = (response as List)
          .map((json) => ActivityModel.fromJson(json))
          .toList();
      
      return Success(activities);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to load activities',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading activities',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<ActivityModel>> getActivity(String id) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('id', id)
          .single();
      
      return Success(ActivityModel.fromJson(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return Failure(AppError(
          message: 'Activity not found',
          type: ErrorType.notFound,
        ));
      }
      return Failure(AppError(
        message: 'Failed to load activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<ActivityModel>> createActivity(ActivityModel activity) async {
    try {
      final response = await _client
          .from('activities')
          .insert(activity.toJson())
          .select()
          .single();
      
      return Success(ActivityModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to create activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error creating activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<ActivityModel>> updateActivity(ActivityModel activity) async {
    try {
      final response = await _client
          .from('activities')
          .update(activity.toJson())
          .eq('id', activity.id!)
          .select()
          .single();
      
      return Success(ActivityModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to update activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error updating activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> deleteActivity(String id) async {
    try {
      await _client.from('activities').delete().eq('id', id);
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to delete activity',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error deleting activity',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<List<ActivityModel>>> getActivitiesByStatus(
    String userId,
    String status,
  ) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('created_by', userId)
          .eq('status', status)
          .order('created_at', ascending: false);
      
      final activities = (response as List)
          .map((json) => ActivityModel.fromJson(json))
          .toList();
      
      return Success(activities);
    } on PostgrestException catch (e) {
      return Failure(AppError(
        message: 'Failed to load activities by status',
        technicalDetails: e.message,
        type: ErrorType.server,
      ));
    } catch (e, stackTrace) {
      return Failure(AppError(
        message: 'Unexpected error loading activities',
        technicalDetails: e.toString(),
        type: ErrorType.unknown,
        stackTrace: stackTrace,
      ));
    }
  }
}
