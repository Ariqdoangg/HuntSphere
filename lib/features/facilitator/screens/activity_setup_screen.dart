import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import 'checkpoint_setup_screen.dart';

class ActivitySetupScreen extends StatefulWidget {
  const ActivitySetupScreen({super.key});

  @override
  State<ActivitySetupScreen> createState() => _ActivitySetupScreenState();
}

class _ActivitySetupScreenState extends State<ActivitySetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  bool _isLoading = false;
  int? _selectedPreset;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Duration presets in minutes
  static const List<Map<String, dynamic>> _durationPresets = [
    {'label': '15 min', 'value': 15, 'description': 'Quick game'},
    {'label': '30 min', 'value': 30, 'description': 'Short session'},
    {'label': '45 min', 'value': 45, 'description': 'Standard'},
    {'label': '60 min', 'value': 60, 'description': '1 hour'},
    {'label': '90 min', 'value': 90, 'description': '1.5 hours'},
    {'label': '120 min', 'value': 120, 'description': '2 hours'},
    {'label': 'Custom', 'value': -1, 'description': 'Set your own'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _createActivity() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if user is logged in
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('You must be logged in to create an activity', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final activity = await SupabaseService.createActivity(
        name: _nameController.text.trim(),
        durationMinutes: int.parse(_durationController.text),
      );

      if (!mounted) return;

      _showSnackBar('Activity created! Join Code: ${activity.joinCode}');

      // Navigate to Checkpoint Setup with Hero animation
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CheckpointSetupScreen(activity: activity),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingM),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      appBar: AppBar(
        title: const Text('Create Activity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with icon
                    _buildHeader(),
                    const SizedBox(height: AppTheme.spacingXL),

                    // Activity Name Input
                    _buildNameInput(),
                    const SizedBox(height: AppTheme.spacingL),

                    // Duration Section
                    _buildDurationSection(),
                    const SizedBox(height: AppTheme.spacingL),

                    // Info Banner
                    const EliteInfoBanner(
                      message:
                          'A unique join code will be generated for participants to join your activity.',
                      icon: Icons.info_outline,
                    ),
                    const SizedBox(height: AppTheme.spacingXL),

                    // Create Button
                    _buildCreateButton(),
                    const SizedBox(height: AppTheme.spacingL),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Animated Icon with glow
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryBlue.withValues(alpha: 0.2),
                      AppTheme.primaryPurple.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 48,
                  color: AppTheme.accent,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacingM),

        // Title with gradient
        const GradientText(
          text: 'Setup Your HuntSphere Event',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          gradient: LinearGradient(
            colors: [AppTheme.accent, AppTheme.primaryBlue],
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),

        Text(
          'Create an activity and configure checkpoints',
          textAlign: TextAlign.center,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EliteTextField(
          controller: _nameController,
          label: 'Activity Name',
          hint: 'e.g., Campus Exploration Race',
          prefixIcon: Icons.title_rounded,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter an activity name';
            }
            if (value.trim().length < 3) {
              return 'Name must be at least 3 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Icon(
                Icons.timer_outlined,
                color: AppTheme.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Activity Duration',
              style: AppTheme.headingSmall.copyWith(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),

        // Duration Presets Grid
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _durationPresets.map((preset) {
            return _buildDurationChip(preset);
          }).toList(),
        ),
        const SizedBox(height: AppTheme.spacingM),

        // Custom Duration Input
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: (_selectedPreset == -1 || _selectedPreset == null)
              ? _buildCustomDurationInput()
              : const SizedBox.shrink(),
        ),

        // Selected Duration Summary
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: (_selectedPreset != null && _selectedPreset != -1)
              ? _buildDurationSummary()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDurationChip(Map<String, dynamic> preset) {
    final isSelected = _selectedPreset == preset['value'];
    final isCustom = preset['value'] == -1;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedPreset = preset['value'];
          if (!isCustom) {
            _durationController.text = preset['value'].toString();
          } else {
            _durationController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppTheme.backgroundElevated.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              preset['label'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preset['description'],
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDurationInput() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingS),
      child: TextFormField(
        controller: _durationController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTheme.bodyLarge,
        decoration: AppTheme.inputDecoration(
          label: 'Custom Duration (minutes)',
          hint: 'Enter duration (10-480 min)',
          prefixIcon: Icons.edit_outlined,
        ).copyWith(
          suffixText: 'min',
          suffixStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter duration';
          }
          final duration = int.tryParse(value);
          if (duration == null) {
            return 'Please enter a valid number';
          }
          if (duration < 10) {
            return 'Duration must be at least 10 minutes';
          }
          if (duration > 480) {
            return 'Duration cannot exceed 8 hours (480 min)';
          }
          return null;
        },
        onChanged: (value) {
          final duration = int.tryParse(value);
          if (duration != null) {
            final matchingPreset = _durationPresets.firstWhere(
              (p) => p['value'] == duration,
              orElse: () => {'value': -1},
            );
            if (matchingPreset['value'] != -1) {
              setState(() => _selectedPreset = duration);
            }
          }
        },
      ),
    );
  }

  Widget _buildDurationSummary() {
    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.success.withValues(alpha: 0.15),
            AppTheme.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.success,
              size: 18,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duration Selected',
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$_selectedPreset minutes (${(_selectedPreset! / 60).toStringAsFixed(1)} hours)',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return EliteButton(
      label: 'Create Activity & Setup Checkpoints',
      onPressed: _isLoading ? null : _createActivity,
      isLoading: _isLoading,
      icon: Icons.arrow_forward_rounded,
    );
  }
}
