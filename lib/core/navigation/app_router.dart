import 'package:flutter/material.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';

/// Typed route arguments for type-safe navigation
abstract class RouteArguments {
  const RouteArguments();
}

/// Arguments for checkpoint tasks screen
class CheckpointTasksArgs extends RouteArguments {
  final String checkpointId;
  final String checkpointName;
  final String teamId;

  const CheckpointTasksArgs({
    required this.checkpointId,
    required this.checkpointName,
    required this.teamId,
  });
}

/// Arguments for photo task screen
class PhotoTaskArgs extends RouteArguments {
  final Map<String, dynamic> task;
  final String teamId;
  final String checkpointName;

  const PhotoTaskArgs({
    required this.task,
    required this.teamId,
    required this.checkpointName,
  });
}

/// Arguments for quiz task screen
class QuizTaskArgs extends RouteArguments {
  final Map<String, dynamic> task;
  final String teamId;

  const QuizTaskArgs({
    required this.task,
    required this.teamId,
  });
}

/// Arguments for QR task screen
class QRTaskArgs extends RouteArguments {
  final Map<String, dynamic> task;
  final String teamId;

  const QRTaskArgs({
    required this.task,
    required this.teamId,
  });
}

/// Arguments for leaderboard screen
class LeaderboardArgs extends RouteArguments {
  final String activityId;
  final String? currentTeamId;

  const LeaderboardArgs({
    required this.activityId,
    this.currentTeamId,
  });
}

/// Arguments for results screen
class ResultsArgs extends RouteArguments {
  final String activityId;
  final bool isFacilitator;

  const ResultsArgs({
    required this.activityId,
    this.isFacilitator = false,
  });
}

/// Arguments for facilitator leaderboard screen
class FacilitatorLeaderboardArgs extends RouteArguments {
  final String activityId;
  final String activityName;

  const FacilitatorLeaderboardArgs({
    required this.activityId,
    required this.activityName,
  });
}

/// Arguments for game map screen
class GameMapArgs extends RouteArguments {
  final String activityId;
  final String teamId;
  final String participantName;

  const GameMapArgs({
    required this.activityId,
    required this.teamId,
    required this.participantName,
  });
}

/// Arguments for facilitator lobby screen
class FacilitatorLobbyArgs extends RouteArguments {
  final ActivityModel activity;

  const FacilitatorLobbyArgs({required this.activity});
}

/// Arguments for checkpoint setup screen
class CheckpointSetupArgs extends RouteArguments {
  final ActivityModel activity;

  const CheckpointSetupArgs({required this.activity});
}

/// Route names as constants
class AppRoutes {
  AppRoutes._();

  // Auth routes
  static const String home = '/';
  static const String facilitatorAuth = '/facilitator-auth';
  static const String participantJoin = '/participant-join';

  // Facilitator routes
  static const String facilitatorDashboard = '/facilitator-dashboard';
  static const String facilitatorLobby = '/facilitator-lobby';
  static const String checkpointSetup = '/checkpoint-setup';
  static const String activitySetup = '/activity-setup';
  static const String facilitatorLeaderboard = '/facilitator-leaderboard';

  // Participant routes
  static const String gameMap = '/game-map';
  static const String checkpointTasks = '/checkpoint-tasks';
  static const String photoTask = '/photo-task';
  static const String quizTask = '/quiz-task';
  static const String qrTask = '/qr-task';
  static const String leaderboard = '/leaderboard';
  static const String results = '/results';
}

/// Type-safe navigation helper
class AppNavigator {
  AppNavigator._();

  /// Navigate to a named route with typed arguments
  static Future<T?> navigateTo<T, A extends RouteArguments>(
    BuildContext context,
    String routeName, {
    A? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  /// Replace current route with a new one
  static Future<T?> replaceTo<T, A extends RouteArguments>(
    BuildContext context,
    String routeName, {
    A? arguments,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, dynamic>(
      routeName,
      arguments: arguments,
    );
  }

  /// Navigate and remove all previous routes
  static Future<T?> navigateAndClearStack<T, A extends RouteArguments>(
    BuildContext context,
    String routeName, {
    A? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil<T>(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Pop current route
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop(result);
  }

  /// Pop until a specific route
  static void popUntil(BuildContext context, String routeName) {
    Navigator.of(context).popUntil(ModalRoute.withName(routeName));
  }

  /// Pop to first route
  static void popToFirst(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Convenience methods for common navigations

  static Future<void> toCheckpointTasks(
    BuildContext context,
    CheckpointTasksArgs args,
  ) {
    return navigateTo(context, AppRoutes.checkpointTasks, arguments: args);
  }

  static Future<void> toPhotoTask(BuildContext context, PhotoTaskArgs args) {
    return navigateTo(context, AppRoutes.photoTask, arguments: args);
  }

  static Future<void> toQuizTask(BuildContext context, QuizTaskArgs args) {
    return navigateTo(context, AppRoutes.quizTask, arguments: args);
  }

  static Future<void> toQRTask(BuildContext context, QRTaskArgs args) {
    return navigateTo(context, AppRoutes.qrTask, arguments: args);
  }

  static Future<void> toLeaderboard(BuildContext context, LeaderboardArgs args) {
    return navigateTo(context, AppRoutes.leaderboard, arguments: args);
  }

  static Future<void> toResults(BuildContext context, ResultsArgs args) {
    return navigateTo(context, AppRoutes.results, arguments: args);
  }

  static Future<void> toFacilitatorLeaderboard(
    BuildContext context,
    FacilitatorLeaderboardArgs args,
  ) {
    return navigateTo(context, AppRoutes.facilitatorLeaderboard, arguments: args);
  }
}

/// Extension to safely extract typed arguments from route
extension RouteArgumentsExtension on BuildContext {
  /// Get typed arguments from current route
  T? getArguments<T extends RouteArguments>() {
    final args = ModalRoute.of(this)?.settings.arguments;
    if (args is T) return args;
    return null;
  }

  /// Get typed arguments or throw
  T requireArguments<T extends RouteArguments>() {
    final args = getArguments<T>();
    if (args == null) {
      throw ArgumentError('Expected arguments of type $T but got null');
    }
    return args;
  }
}

/// Mixin for extracting arguments in StatefulWidget
mixin RouteArgumentsMixin<T extends StatefulWidget> on State<T> {
  /// Get typed arguments safely
  A? getArgs<A extends RouteArguments>() {
    return context.getArguments<A>();
  }

  /// Get typed arguments or throw
  A requireArgs<A extends RouteArguments>() {
    return context.requireArguments<A>();
  }
}
