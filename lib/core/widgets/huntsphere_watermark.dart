import 'package:flutter/material.dart';
import 'package:huntsphere/core/theme/app_theme.dart';

/// A reusable floating watermark component that displays the HuntSphere logo and name.
///
/// This widget is designed for subtle branding on game screens and other content-heavy
/// pages where prominent branding would be distracting. It creates a translucent chip
/// with the logo and app name.
///
/// Example usage:
/// ```dart
/// Stack(
///   children: [
///     // Main content
///     MyGameContent(),
///
///     // Add watermark
///     const HuntSphereWatermark(
///       alignment: Alignment.topRight,
///       opacity: 0.6,
///     ),
///   ],
/// )
/// ```
class HuntSphereWatermark extends StatelessWidget {
  /// The alignment of the watermark within its parent.
  ///
  /// Typically [Alignment.topRight] or [Alignment.topLeft] to keep it in a corner
  /// and avoid obstructing main content.
  final Alignment alignment;

  /// The opacity of the watermark (0.0 to 1.0).
  ///
  /// Lower values (0.4-0.6) create a subtle effect, while higher values (0.7-0.9)
  /// make the branding more prominent. Default is 0.7.
  final double opacity;

  const HuntSphereWatermark({
    super.key,
    this.alignment = Alignment.topRight,
    this.opacity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withOpacity(0.15),
              AppTheme.primaryPurple.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Opacity(
          opacity: opacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EliteLogo(size: 20, showGlow: false),
              const SizedBox(width: 6),
              GradientText(
                text: 'HuntSphere',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryPurple],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
