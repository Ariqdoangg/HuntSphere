import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/error_handler.dart';
import '../../../services/activity_service.dart';
import '../../../services/cache_service.dart';
import 'selfie_capture_screen.dart';

class ParticipantJoinScreen extends StatefulWidget {
  const ParticipantJoinScreen({super.key});

  @override
  State<ParticipantJoinScreen> createState() => _ParticipantJoinScreenState();
}

class _ParticipantJoinScreenState extends State<ParticipantJoinScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinActivity() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate join code format before querying
    final joinCode = _codeController.text.trim().toUpperCase();
    final codeValidation = Validators.validateJoinCode(joinCode);
    if (codeValidation != null) {
      ErrorHandler.showError(context, codeValidation);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final activityService = ActivityService(
        Supabase.instance.client,
        CacheService(),
      );
      final result = await activityService.getActivityByJoinCode(joinCode);

      if (!result.isSuccess || result.data == null) {
        if (mounted) {
          ErrorHandler.showError(context, 'Activity not found. Please check the code.');
        }
        return;
      }

      final activity = result.data!;

      // Check if activity is open for joining
      if (activity.status != 'setup' && activity.status != 'lobby') {
        if (mounted) {
          ErrorHandler.showError(context, 'This activity has already started or ended.');
        }
        return;
      }

      // Navigate to selfie screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelfieCaptureScreen(
              activity: activity,
              participantName: _nameController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Join activity error: $e');
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to join activity. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios),
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // Logo
                  const EliteLogo(size: 100),
                  const SizedBox(height: AppTheme.spacingL),

                  // Title
                  const GradientText(
                    text: 'HuntSphere',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),

                  // Subtitle
                  Text(
                    'Join the Adventure',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL * 1.5),

                  // Form
                  _buildForm(),
                  const SizedBox(height: AppTheme.spacingL),

                  // Info card
                  const EliteInfoBanner(
                    icon: Icons.info_outline,
                    message: 'Get the join code from your facilitator',
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: EliteButton(
                      onPressed: _joinActivity,
                      icon: Icons.login,
                      label: 'Join Activity',
                      isLoading: _isLoading,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name field
          EliteTextField(
            controller: _nameController,
            label: 'Your Name',
            prefixIcon: Icons.person_outline,
            hint: 'Enter your full name',
            textCapitalization: TextCapitalization.words,
            validator: Validators.validateName,
          ),
          const SizedBox(height: AppTheme.spacingM),

          // Join code field
          EliteTextField(
            controller: _codeController,
            label: 'Join Code',
            prefixIcon: Icons.vpn_key_outlined,
            hint: 'e.g. UPSI24',
            textCapitalization: TextCapitalization.characters,
            validator: Validators.validateJoinCode,
          ),
        ],
      ),
    );
  }
}
