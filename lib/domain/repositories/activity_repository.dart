import 'package:huntsphere/core/utils/result.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';

/// Abstract repository for activity data operations
/// Defines the contract for activity data access without implementation details
abstract class ActivityRepository {
  /// Get all activities for a facilitator
  Future<Result<List<ActivityModel>>> getActivities(String userId);
  
  /// Get a single activity by ID
  Future<Result<ActivityModel>> getActivity(String id);
  
  /// Create a new activity
  Future<Result<ActivityModel>> createActivity(ActivityModel activity);
  
  /// Update an existing activity
  Future<Result<ActivityModel>> updateActivity(ActivityModel activity);
  
  /// Delete an activity
  Future<Result<void>> deleteActivity(String id);
  
  /// Get activities with status filter
  Future<Result<List<ActivityModel>>> getActivitiesByStatus(
    String userId, 
    String status,
  );
}
