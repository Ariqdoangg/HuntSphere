import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'features/facilitator/screens/facilitator_auth_screen.dart';
import 'features/facilitator/screens/facilitator_dashboard.dart';

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
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (mounted) {
        if (session != null) {
          // User is logged in, check if approved
          _checkFacilitatorStatus();
        } else {
          // User is not logged in
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const FacilitatorAuthScreen(),
            ),
          );
        }
      }
    });
  }

  Future<void> _checkFacilitatorStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final facilData = await Supabase.instance.client
          .from('facilitators')
          .select()
          .eq('user_id', userId)
          .single();

      if (facilData['status'] == 'approved' && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const FacilitatorDashboard(),
          ),
        );
      } else {
        // Not approved, sign out
        await Supabase.instance.client.auth.signOut();
      }
    } catch (e) {
      // Error or not found, sign out
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
