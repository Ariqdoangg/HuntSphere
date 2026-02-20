import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'services/connectivity_service.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'services/audio_service.dart';
import 'features/facilitator/screens/facilitator_auth_screen.dart';
import 'features/participant/screens/participant_join_screen.dart';
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
      home: const AuthChecker(),
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

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: child,
                ),
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXL,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: AppTheme.spacingXXL),

                  // Elite Logo
                  const EliteLogo(size: 120),
                  const SizedBox(height: AppTheme.spacingL),

                  // App Title with gradient
                  const GradientText(
                    text: 'HuntSphere',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // Tagline
                  Text(
                    'GPS Treasure Hunt Platform',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXXL * 1.5),

                  // Facilitator Button
                  SizedBox(
                    width: 280,
                    child: EliteButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FacilitatorAuthScreen(),
                          ),
                        );
                      },
                      icon: Icons.admin_panel_settings,
                      label: 'Facilitator',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // Participant Button
                  SizedBox(
                    width: 280,
                    child: EliteButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ParticipantJoinScreen(),
                          ),
                        );
                      },
                      icon: Icons.group,
                      label: 'Join Activity',
                      isOutlined: true,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingXXL),

                  // Version info
                  Text(
                    'v1.0.0',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
