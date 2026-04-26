import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants_secure.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'services/connectivity_service.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'services/audio_service.dart';
import 'features/home_screen.dart';
import 'features/participant/screens/checkpoint_tasks_screen.dart';
import 'features/participant/screens/photo_task_screen.dart';
import 'features/participant/screens/quiz_task_screen.dart';
import 'features/participant/screens/qr_task_screen.dart';
import 'features/participant/screens/leaderboard_screen.dart';
import 'features/participant/screens/results_screen.dart';
import 'features/facilitator/screens/facilitator_leaderboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (may fail on web if .env not bundled)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Failed to load .env file: $e');
    debugPrint('Falling back to --dart-define environment variables');
  }

  // Validate Supabase configuration
  SupabaseConstants.validateConfig();
  SupabaseConstants.validateForDevelopment();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  // Initialize services with error handling
  try {
    await Future.wait([
      ConnectivityService().initialize(),
      CacheService().initialize(),
      NotificationService().initialize(),
      AudioService().initialize(),
    ]);
  } catch (e) {
    debugPrint('Service initialization error (non-fatal): $e');
  }

  runApp(
    const ProviderScope(
      child: HuntSphereApp(),
    ),
  );
}

class HuntSphereApp extends StatelessWidget {
  const HuntSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HuntSphere',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const HomeScreen(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// Generate routes with typed arguments
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.checkpointTasks:
        final args = settings.arguments;
        if (args is CheckpointTasksArgs) {
          return MaterialPageRoute(
            builder: (context) => CheckpointTasksScreen(
              checkpointId: args.checkpointId,
              checkpointName: args.checkpointName,
              teamId: args.teamId,
            ),
            settings: settings,
          );
        }
        // Fallback for old-style Map arguments (backward compatibility)
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (context) => CheckpointTasksScreen(
              checkpointId: args['checkpointId'],
              checkpointName: args['checkpointName'],
              teamId: args['teamId'],
            ),
            settings: settings,
          );
        }
        return _errorRoute('Invalid arguments for checkpoint tasks');

      case AppRoutes.photoTask:
        final args = settings.arguments;
        if (args is PhotoTaskArgs) {
          return MaterialPageRoute(
            builder: (context) => PhotoTaskScreen(
              task: args.task,
              teamId: args.teamId,
              checkpointName: args.checkpointName,
            ),
            settings: settings,
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (context) => PhotoTaskScreen(
              task: args['task'],
              teamId: args['teamId'],
              checkpointName: args['checkpointName'],
            ),
            settings: settings,
          );
        }
        return _errorRoute('Invalid arguments for photo task');

      case AppRoutes.quizTask:
        final args = settings.arguments;
        if (args is QuizTaskArgs) {
          return MaterialPageRoute(
            builder: (context) => QuizTaskScreen(
              task: args.task,
              teamId: args.teamId,
            ),
            settings: settings,
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (context) => QuizTaskScreen(
              task: args['task'],
              teamId: args['teamId'],
            ),
            settings: settings,
          );
        }
        return _errorRoute('Invalid arguments for quiz task');

      case AppRoutes.qrTask:
        final args = settings.arguments;
        if (args is QRTaskArgs) {
          return MaterialPageRoute(
            builder: (context) => QRTaskScreen(
              task: args.task,
              teamId: args.teamId,
            ),
            settings: settings,
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (context) => QRTaskScreen(
              task: args['task'],
              teamId: args['teamId'],
            ),
            settings: settings,
          );
        }
        return _errorRoute('Invalid arguments for QR task');

      case AppRoutes.leaderboard:
        final args = settings.arguments;
        if (args is LeaderboardArgs) {
          return MaterialPageRoute(
            builder: (context) => LeaderboardScreen(
              activityId: args.activityId,
              currentTeamId: args.currentTeamId,
            ),
            settings: settings,
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (context) => LeaderboardScreen(
              activityId: args['activityId'],
              currentTeamId: args['currentTeamId'],
            ),
            settings: settings,
          );
        }
        return _errorRoute('Invalid arguments for leaderboard');

      case AppRoutes.results:
        final args = settings.arguments;
        if (args is ResultsArgs) {
          return MaterialPageRoute(
            builder: (context) => ResultsScreen(
              activityId: args.activityId,
              isFacilitator: args.isFacilitator,
            ),
            settings: settings,
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (context) => ResultsScreen(
              activityId: args['activityId'],
              isFacilitator: args['isFacilitator'] ?? false,
            ),
            settings: settings,
          );
        }
        return _errorRoute('Invalid arguments for results');

      case AppRoutes.facilitatorLeaderboard:
        final args = settings.arguments;
        if (args is FacilitatorLeaderboardArgs) {
          return MaterialPageRoute(
            builder: (context) => FacilitatorLeaderboardScreen(
              activityId: args.activityId,
              activityName: args.activityName,
            ),
            settings: settings,
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (context) => FacilitatorLeaderboardScreen(
              activityId: args['activityId'],
              activityName: args['activityName'],
            ),
            settings: settings,
          );
        }
        return _errorRoute('Invalid arguments for facilitator leaderboard');

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  /// Create an error route for invalid navigation
  Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

