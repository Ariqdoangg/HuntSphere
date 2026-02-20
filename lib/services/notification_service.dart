import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Notification types for the app
enum NotificationType {
  gameStarted,
  gameEnded,
  checkpointCompleted,
  taskCompleted,
  teamJoined,
  rankChanged,
  timeWarning,
  newAchievement,
}

/// Notification payload data
class NotificationPayload {
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;

  NotificationPayload({
    required this.type,
    required this.title,
    required this.body,
    this.data,
  });
}

/// Service for handling local and push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Stream controller for notification taps
  final _notificationTapController =
      StreamController<NotificationPayload>.broadcast();
  Stream<NotificationPayload> get onNotificationTap =>
      _notificationTapController.stream;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Skip initialization on web - local notifications not supported
    if (kIsWeb) {
      _isInitialized = true;
      debugPrint('NotificationService: Web platform - notifications disabled');
      return;
    }

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions on iOS
    if (!kIsWeb && Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Request permissions on Android 13+
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // Initialize timezone
    tz_data.initializeTimeZones();

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Parse payload and emit to stream
    if (response.payload != null) {
      // You can parse JSON payload here and create NotificationPayload
    }
  }

  /// Show a local notification
  Future<void> showNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.gameStarted,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) await initialize();

    // Skip on web - local notifications not supported
    if (kIsWeb) {
      debugPrint('Notification (web): $title - $body');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'huntsphere_${type.name}',
      _getChannelName(type),
      channelDescription: _getChannelDescription(type),
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: _getNotificationColor(type),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data?.toString(),
    );
  }

  /// Show game started notification
  Future<void> notifyGameStarted(String activityName) async {
    await showNotification(
      title: 'Game Started!',
      body: '$activityName has begun. Good luck!',
      type: NotificationType.gameStarted,
    );
  }

  /// Show game ended notification
  Future<void> notifyGameEnded(String activityName, {int? rank}) async {
    final rankText = rank != null ? ' You finished #$rank!' : '';
    await showNotification(
      title: 'Game Over!',
      body: '$activityName has ended.$rankText',
      type: NotificationType.gameEnded,
    );
  }

  /// Show checkpoint completed notification
  Future<void> notifyCheckpointCompleted(
    String checkpointName, {
    int? pointsEarned,
  }) async {
    final pointsText = pointsEarned != null ? ' (+$pointsEarned pts)' : '';
    await showNotification(
      title: 'Checkpoint Complete!',
      body: 'You completed $checkpointName$pointsText',
      type: NotificationType.checkpointCompleted,
    );
  }

  /// Show rank changed notification
  Future<void> notifyRankChanged(int newRank, {bool improved = true}) async {
    await showNotification(
      title: improved ? 'Rank Up!' : 'Rank Changed',
      body: improved
          ? 'You moved up to position #$newRank!'
          : 'You are now at position #$newRank',
      type: NotificationType.rankChanged,
    );
  }

  /// Show time warning notification
  Future<void> notifyTimeWarning(int minutesRemaining) async {
    await showNotification(
      title: 'Time Warning',
      body: 'Only $minutesRemaining minutes remaining!',
      type: NotificationType.timeWarning,
    );
  }

  /// Show team joined notification (for facilitators)
  Future<void> notifyTeamJoined(String teamName, int totalTeams) async {
    await showNotification(
      title: 'New Team Joined',
      body: '$teamName has joined! ($totalTeams teams total)',
      type: NotificationType.teamJoined,
    );
  }

  /// Schedule a notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    NotificationType type = NotificationType.timeWarning,
  }) async {
    if (!_isInitialized) await initialize();

    // Skip on web - scheduled notifications not supported
    if (kIsWeb) {
      debugPrint('Scheduled notification (web): $title at $scheduledTime');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'huntsphere_scheduled',
      'Scheduled Notifications',
      channelDescription: 'Scheduled game notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _localNotifications.cancel(id);
  }

  String _getChannelName(NotificationType type) {
    switch (type) {
      case NotificationType.gameStarted:
      case NotificationType.gameEnded:
        return 'Game Updates';
      case NotificationType.checkpointCompleted:
      case NotificationType.taskCompleted:
        return 'Progress Updates';
      case NotificationType.teamJoined:
        return 'Team Updates';
      case NotificationType.rankChanged:
        return 'Leaderboard Updates';
      case NotificationType.timeWarning:
        return 'Time Alerts';
      case NotificationType.newAchievement:
        return 'Achievements';
    }
  }

  String _getChannelDescription(NotificationType type) {
    switch (type) {
      case NotificationType.gameStarted:
      case NotificationType.gameEnded:
        return 'Notifications about game start and end';
      case NotificationType.checkpointCompleted:
      case NotificationType.taskCompleted:
        return 'Notifications about your progress';
      case NotificationType.teamJoined:
        return 'Notifications when teams join';
      case NotificationType.rankChanged:
        return 'Notifications about leaderboard changes';
      case NotificationType.timeWarning:
        return 'Warnings about remaining time';
      case NotificationType.newAchievement:
        return 'Notifications about achievements';
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.gameStarted:
        return const Color(0xFF4CAF50);
      case NotificationType.gameEnded:
        return const Color(0xFF2196F3);
      case NotificationType.checkpointCompleted:
      case NotificationType.taskCompleted:
        return const Color(0xFFFF9800);
      case NotificationType.rankChanged:
        return const Color(0xFFFFD700);
      case NotificationType.timeWarning:
        return const Color(0xFFF44336);
      case NotificationType.teamJoined:
        return const Color(0xFF9C27B0);
      case NotificationType.newAchievement:
        return const Color(0xFFE91E63);
    }
  }

  void dispose() {
    _notificationTapController.close();
  }
}
