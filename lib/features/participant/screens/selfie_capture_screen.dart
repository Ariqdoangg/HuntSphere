import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';
import 'waiting_lobby_screen.dart';

class SelfieCaptureScreen extends StatefulWidget {
  final ActivityModel activity;
  final String participantName;

  const SelfieCaptureScreen({
    super.key,
    required this.activity,
    required this.participantName,
  });

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  XFile? _capturedImage;
  Uint8List? _imageBytes;
  bool _isUploading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    HapticFeedback.mediumImpact();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _capturedImage = image;
          _imageBytes = bytes;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error accessing camera: $e')),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            margin: const EdgeInsets.all(AppTheme.spacingM),
          ),
        );
      }
    }
  }

  Future<void> _retake() async {
    HapticFeedback.lightImpact();
    setState(() {
      _capturedImage = null;
      _imageBytes = null;
    });
  }

  Future<void> _submitAndJoin() async {
    if (_capturedImage == null || _imageBytes == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isUploading = true);

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${widget.participantName}.jpg';

      await Supabase.instance.client.storage
          .from('selfies')
          .uploadBinary(fileName, _imageBytes!);

      final selfieUrl = Supabase.instance.client.storage
          .from('selfies')
          .getPublicUrl(fileName);

      final participantData = await Supabase.instance.client
          .from('participants')
          .insert({
            'activity_id': widget.activity.id,
            'name': widget.participantName,
            'selfie_url': selfieUrl,
            'joined_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final participant = ParticipantModel.fromJson(participantData);

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                WaitingLobbyScreen(
              activity: widget.activity,
              participant: participant,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error joining activity: $e')),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            margin: const EdgeInsets.all(AppTheme.spacingM),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      appBar: AppBar(
        title: const Text('Take Selfie'),
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
        child: _capturedImage != null && _imageBytes != null
            ? _buildPreviewScreen()
            : _buildCaptureScreen(),
      ),
    );
  }

  Widget _buildCaptureScreen() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Camera Icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.3),
                        AppTheme.primaryPurple.withValues(alpha: 0.2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accent,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 60,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Title with Gradient
              const GradientText(
                text: 'Take Your Selfie',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                gradient: LinearGradient(
                  colors: [AppTheme.accent, AppTheme.primaryPurple],
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Name Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.2),
                      AppTheme.primaryPurple.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      widget.participantName,
                      style: AppTheme.headingSmall.copyWith(
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Instructions Card
              EliteCard(
                showBorder: true,
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.face_rounded,
                      'Show your face clearly',
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    _buildInfoRow(
                      Icons.wb_sunny_rounded,
                      'Ensure good lighting',
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    _buildInfoRow(
                      Icons.camera_rounded,
                      'Browser will ask for camera permission',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Open Camera Button
              EliteButton(
                label: 'Open Camera',
                icon: Icons.camera_alt_rounded,
                onPressed: _takePicture,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: AppTheme.accent, size: 20),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewScreen() {
    return Column(
      children: [
        // Preview Image
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusL - 2),
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Success Message
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.success.withValues(alpha: 0.2),
                AppTheme.success.withValues(alpha: 0.1),
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
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Looking good!',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Confirm to join the activity',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              // Retake Button
              Expanded(
                child: _buildOutlinedButton(
                  label: 'Retake',
                  icon: Icons.refresh_rounded,
                  onPressed: _isUploading ? null : _retake,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),

              // Confirm Button
              Expanded(
                child: EliteButton(
                  label: _isUploading ? 'Joining...' : 'Confirm',
                  icon: _isUploading ? null : Icons.check_rounded,
                  onPressed: _isUploading ? null : _submitAndJoin,
                  isLoading: _isUploading,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutlinedButton({
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.accent,
          side: const BorderSide(color: AppTheme.accent, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
        ),
      ),
    );
  }
}
