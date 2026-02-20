import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huntsphere/services/notification_service.dart';

/// Notification service provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Notification settings state
class NotificationSettings {
  final bool gameUpdates;
  final bool progressUpdates;
  final bool leaderboardUpdates;
  final bool timeWarnings;

  const NotificationSettings({
    this.gameUpdates = true,
    this.progressUpdates = true,
    this.leaderboardUpdates = true,
    this.timeWarnings = true,
  });

  NotificationSettings copyWith({
    bool? gameUpdates,
    bool? progressUpdates,
    bool? leaderboardUpdates,
    bool? timeWarnings,
  }) {
    return NotificationSettings(
      gameUpdates: gameUpdates ?? this.gameUpdates,
      progressUpdates: progressUpdates ?? this.progressUpdates,
      leaderboardUpdates: leaderboardUpdates ?? this.leaderboardUpdates,
      timeWarnings: timeWarnings ?? this.timeWarnings,
    );
  }
}

/// Notification settings notifier
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings());

  void toggleGameUpdates() {
    state = state.copyWith(gameUpdates: !state.gameUpdates);
  }

  void toggleProgressUpdates() {
    state = state.copyWith(progressUpdates: !state.progressUpdates);
  }

  void toggleLeaderboardUpdates() {
    state = state.copyWith(leaderboardUpdates: !state.leaderboardUpdates);
  }

  void toggleTimeWarnings() {
    state = state.copyWith(timeWarnings: !state.timeWarnings);
  }

  void setAll(bool enabled) {
    state = NotificationSettings(
      gameUpdates: enabled,
      progressUpdates: enabled,
      leaderboardUpdates: enabled,
      timeWarnings: enabled,
    );
  }
}

/// Notification settings provider
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(),
);
