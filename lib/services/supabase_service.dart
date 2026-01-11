import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'dart:math';
import 'package:huntsphere/features/shared/models/checkpoint_model.dart';
import 'package:huntsphere/features/shared/models/task_model.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Generate a random 6-character join code
  static String generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // Create a new activity
  static Future<ActivityModel> createActivity({
    required String name,
    required int durationMinutes,
  }) async {
    try {
      // ✅ FIX: Get current user ID
      final userId = _client.auth.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User must be logged in to create an activity');
      }
      
      // Generate unique join code
      String joinCode = generateJoinCode();

      // Check if join code already exists
      final existing = await _client
          .from('activities')
          .select()
          .eq('join_code', joinCode)
          .maybeSingle();

      if (existing != null) {
        joinCode = generateJoinCode();
      }

      // ✅ FIX: Create data with created_by field
      final activityData = {
        'name': name,
        'join_code': joinCode,
        'total_duration_minutes': durationMinutes,
        'status': 'setup',
        'created_by': userId,  // ✅ THIS IS THE FIX!
        'created_at': DateTime.now().toIso8601String(),
      };

      // Insert into database
      final response = await _client
          .from('activities')
          .insert(activityData)
          .select()
          .single();

      return ActivityModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create activity: $e');
    }
  }

  // Get activity by ID
  static Future<ActivityModel?> getActivity(String activityId) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('id', activityId)
          .single();

      return ActivityModel.fromJson(response);
    } catch (e) {
      print('Error fetching activity: $e');
      return null;
    }
  }

  // Update activity status
  static Future<void> updateActivityStatus(
    String activityId,
    String status,
  ) async {
    try {
      await _client
          .from('activities')
          .update({'status': status}).eq('id', activityId);
    } catch (e) {
      throw Exception('Failed to update activity status: $e');
    }
  }
  // ============================================
  // CHECKPOINT METHODS
  // ============================================

  static Future<CheckpointModel> createCheckpoint(
      CheckpointModel checkpoint) async {
    try {
      final response = await _client
          .from('checkpoints')
          .insert(checkpoint.toJson())
          .select()
          .single();

      return CheckpointModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create checkpoint: $e');
    }
  }

  static Future<List<CheckpointModel>> getCheckpoints(String activityId) async {
    try {
      final response = await _client
          .from('checkpoints')
          .select()
          .eq('activity_id', activityId)
          .order('sequence_order');

      return (response as List)
          .map((json) => CheckpointModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch checkpoints: $e');
    }
  }

  static Future<void> deleteCheckpoint(String checkpointId) async {
    try {
      await _client.from('checkpoints').delete().eq('id', checkpointId);
    } catch (e) {
      throw Exception('Failed to delete checkpoint: $e');
    }
  }

  // ============================================
  // TASK METHODS
  // ============================================

  static Future<TaskModel> createTask(TaskModel task) async {
    try {
      final response =
          await _client.from('tasks').insert(task.toJson()).select().single();

      return TaskModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  static Future<List<TaskModel>> getTasks(String checkpointId) async {
    try {
      final response = await _client
          .from('tasks')
          .select()
          .eq('checkpoint_id', checkpointId);

      return (response as List)
          .map((json) => TaskModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tasks: $e');
    }
  }
}