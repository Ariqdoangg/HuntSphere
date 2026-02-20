import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A consistent loading indicator widget for the app
class AppLoading extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const AppLoading({
    super.key,
    this.message,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppTheme.primaryBlue,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Creates a full-screen loading overlay
  static Widget overlay({String? message}) {
    return Container(
      color: AppTheme.backgroundDark.withValues(alpha: 0.8),
      child: AppLoading(message: message),
    );
  }

  /// Creates an inline small loading indicator
  static Widget inline({double size = 20, Color? color}) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppTheme.primaryBlue,
        ),
      ),
    );
  }
}

/// A loading button that shows a spinner when loading
class AppLoadingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isPrimary;

  const AppLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: isLoading ? null : AppTheme.primaryGradient,
          color: isLoading ? AppTheme.backgroundCard : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: isLoading ? null : AppTheme.primaryShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            child: Center(
              child: isLoading
                  ? AppLoading.inline(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(label, style: AppTheme.buttonLarge),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    // Secondary button style
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Center(
            child: isLoading
                ? AppLoading.inline(color: AppTheme.primaryBlue)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: AppTheme.buttonLarge.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
