import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'features/facilitator/screens/facilitator_auth_screen.dart';
import 'features/facilitator/screens/facilitator_dashboard.dart';
import 'features/participant/screens/participant_join_screen.dart';
import 'package:huntsphere/features/participant/screens/checkpoint_tasks_screen.dart';
import 'package:huntsphere/features/participant/screens/photo_task_screen.dart';
import 'package:huntsphere/features/participant/screens/quiz_task_screen.dart';
import 'package:huntsphere/features/participant/screens/qr_task_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  runApp(const HuntSphereApp());
}

class HuntSphereApp extends StatelessWidget {
  const HuntSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HuntSphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D9FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        useMaterial3: true,
      ),
      home: const AuthChecker(),

      // ✅ ADD THESE ROUTES
      routes: {
        '/checkpoint-tasks': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return CheckpointTasksScreen(
            checkpointId: args['checkpointId'],
            checkpointName: args['checkpointName'],
            teamId: args['teamId'],
          );
        },
        '/photo-task': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return PhotoTaskScreen(
            task: args['task'],
            teamId: args['teamId'],
            checkpointName: args['checkpointName'],
          );
        },
        '/quiz-task': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return QuizTaskScreen(
            task: args['task'],
            teamId: args['teamId'],
          );
        },
        '/qr-task': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return QRTaskScreen(
            task: args['task'],
            teamId: args['teamId'],
          );
        },
      },
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            const Icon(
              Icons.location_city,
              size: 100,
              color: Color(0xFF00D9FF),
            ),
            const SizedBox(height: 20),
            const Text(
              '🎯 HuntSphere',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00D9FF),
              ),
            ),
            const SizedBox(height: 60),

            // Facilitator Button
            SizedBox(
              width: 250,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FacilitatorAuthScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text(
                  'Facilitator',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Participant Button
            SizedBox(
              width: 250,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ParticipantJoinScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.group),
                label: const Text(
                  'Join Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
