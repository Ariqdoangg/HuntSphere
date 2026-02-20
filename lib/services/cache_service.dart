import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Cache service for offline data persistence
class CacheService {
  static const String _activitiesBox = 'activities';
  static const String _teamsBox = 'teams';
  static const String _checkpointsBox = 'checkpoints';
  static const String _leaderboardBox = 'leaderboard';
  static const String _settingsBox = 'settings';

  bool _isInitialized = false;

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      await Future.wait([
        Hive.openBox<Map>(_activitiesBox),
        Hive.openBox<Map>(_teamsBox),
        Hive.openBox<Map>(_checkpointsBox),
        Hive.openBox<Map>(_leaderboardBox),
        Hive.openBox<dynamic>(_settingsBox),
      ]);

      _isInitialized = true;
      debugPrint('CacheService initialized successfully');
    } catch (e) {
      debugPrint('CacheService initialization error: $e');
    }
  }

  /// Get a box, ensuring it's open
  Box<T> _getBox<T>(String name) {
    if (!Hive.isBoxOpen(name)) {
      throw Exception('Box $name is not open. Call initialize() first.');
    }
    return Hive.box<T>(name);
  }

  // ============================================================
  // ACTIVITIES CACHE
  // ============================================================

  /// Cache activities list
  Future<void> cacheActivities(String userId, List<Map<String, dynamic>> activities) async {
    try {
      final box = _getBox<Map>(_activitiesBox);
      await box.put(userId, {
        'data': activities,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('CacheService.cacheActivities error: $e');
    }
  }

  /// Get cached activities
  List<Map<String, dynamic>>? getCachedActivities(String userId, {Duration maxAge = const Duration(minutes: 5)}) {
    try {
      final box = _getBox<Map>(_activitiesBox);
      final cached = box.get(userId);

      if (cached == null) return null;

      final timestamp = cached['timestamp'] as int?;
      if (timestamp == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > maxAge.inMilliseconds) return null;

      final data = cached['data'] as List?;
      return data?.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('CacheService.getCachedActivities error: $e');
      return null;
    }
  }

  /// Cache single activity
  Future<void> cacheActivity(String activityId, Map<String, dynamic> activity) async {
    try {
      final box = _getBox<Map>(_activitiesBox);
      await box.put('activity_$activityId', {
        'data': activity,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('CacheService.cacheActivity error: $e');
    }
  }

  /// Get cached activity
  Map<String, dynamic>? getCachedActivity(String activityId, {Duration maxAge = const Duration(minutes: 5)}) {
    try {
      final box = _getBox<Map>(_activitiesBox);
      final cached = box.get('activity_$activityId');

      if (cached == null) return null;

      final timestamp = cached['timestamp'] as int?;
      if (timestamp == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > maxAge.inMilliseconds) return null;

      return (cached['data'] as Map?)?.cast<String, dynamic>();
    } catch (e) {
      debugPrint('CacheService.getCachedActivity error: $e');
      return null;
    }
  }

  // ============================================================
  // TEAMS CACHE
  // ============================================================

  /// Cache teams for an activity
  Future<void> cacheTeams(String activityId, List<Map<String, dynamic>> teams) async {
    try {
      final box = _getBox<Map>(_teamsBox);
      await box.put(activityId, {
        'data': teams,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('CacheService.cacheTeams error: $e');
    }
  }

  /// Get cached teams
  List<Map<String, dynamic>>? getCachedTeams(String activityId, {Duration maxAge = const Duration(seconds: 30)}) {
    try {
      final box = _getBox<Map>(_teamsBox);
      final cached = box.get(activityId);

      if (cached == null) return null;

      final timestamp = cached['timestamp'] as int?;
      if (timestamp == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > maxAge.inMilliseconds) return null;

      final data = cached['data'] as List?;
      return data?.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('CacheService.getCachedTeams error: $e');
      return null;
    }
  }

  // ============================================================
  // LEADERBOARD CACHE
  // ============================================================

  /// Cache leaderboard for an activity
  Future<void> cacheLeaderboard(String activityId, List<Map<String, dynamic>> leaderboard) async {
    try {
      final box = _getBox<Map>(_leaderboardBox);
      await box.put(activityId, {
        'data': leaderboard,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('CacheService.cacheLeaderboard error: $e');
    }
  }

  /// Get cached leaderboard
  List<Map<String, dynamic>>? getCachedLeaderboard(String activityId, {Duration maxAge = const Duration(seconds: 10)}) {
    try {
      final box = _getBox<Map>(_leaderboardBox);
      final cached = box.get(activityId);

      if (cached == null) return null;

      final timestamp = cached['timestamp'] as int?;
      if (timestamp == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > maxAge.inMilliseconds) return null;

      final data = cached['data'] as List?;
      return data?.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('CacheService.getCachedLeaderboard error: $e');
      return null;
    }
  }

  // ============================================================
  // CHECKPOINTS CACHE
  // ============================================================

  /// Cache checkpoints for an activity
  Future<void> cacheCheckpoints(String activityId, List<Map<String, dynamic>> checkpoints) async {
    try {
      final box = _getBox<Map>(_checkpointsBox);
      await box.put(activityId, {
        'data': checkpoints,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('CacheService.cacheCheckpoints error: $e');
    }
  }

  /// Get cached checkpoints
  List<Map<String, dynamic>>? getCachedCheckpoints(String activityId, {Duration maxAge = const Duration(minutes: 5)}) {
    try {
      final box = _getBox<Map>(_checkpointsBox);
      final cached = box.get(activityId);

      if (cached == null) return null;

      final timestamp = cached['timestamp'] as int?;
      if (timestamp == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > maxAge.inMilliseconds) return null;

      final data = cached['data'] as List?;
      return data?.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('CacheService.getCachedCheckpoints error: $e');
      return null;
    }
  }

  // ============================================================
  // SETTINGS CACHE
  // ============================================================

  /// Save a setting
  Future<void> saveSetting(String key, dynamic value) async {
    try {
      final box = _getBox<dynamic>(_settingsBox);
      await box.put(key, value);
    } catch (e) {
      debugPrint('CacheService.saveSetting error: $e');
    }
  }

  /// Get a setting
  T? getSetting<T>(String key, {T? defaultValue}) {
    try {
      final box = _getBox<dynamic>(_settingsBox);
      return box.get(key, defaultValue: defaultValue) as T?;
    } catch (e) {
      debugPrint('CacheService.getSetting error: $e');
      return defaultValue;
    }
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Clear all caches
  Future<void> clearAll() async {
    try {
      await Future.wait([
        _getBox<Map>(_activitiesBox).clear(),
        _getBox<Map>(_teamsBox).clear(),
        _getBox<Map>(_checkpointsBox).clear(),
        _getBox<Map>(_leaderboardBox).clear(),
      ]);
      debugPrint('All caches cleared');
    } catch (e) {
      debugPrint('CacheService.clearAll error: $e');
    }
  }

  /// Clear activities cache for a user
  Future<void> clearActivitiesCache(String userId) async {
    try {
      final box = _getBox<Map>(_activitiesBox);
      await box.delete(userId);
    } catch (e) {
      debugPrint('CacheService.clearActivitiesCache error: $e');
    }
  }

  /// Invalidate all caches for an activity
  Future<void> invalidateActivityCaches(String activityId) async {
    try {
      await Future.wait([
        _getBox<Map>(_activitiesBox).delete('activity_$activityId'),
        _getBox<Map>(_teamsBox).delete(activityId),
        _getBox<Map>(_checkpointsBox).delete(activityId),
        _getBox<Map>(_leaderboardBox).delete(activityId),
      ]);
    } catch (e) {
      debugPrint('CacheService.invalidateActivityCaches error: $e');
    }
  }

  /// Close all boxes
  Future<void> dispose() async {
    try {
      await Hive.close();
      _isInitialized = false;
    } catch (e) {
      debugPrint('CacheService.dispose error: $e');
    }
  }
}
