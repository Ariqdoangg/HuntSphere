import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// HuntSphere Elite Theme System
/// A consistent, premium dark theme with gradient accents
class AppTheme {
  AppTheme._();

  // ============================================================
  // BRAND COLORS
  // ============================================================

  /// Primary brand gradient colors
  static const Color primaryBlue = Color(0xFF4A90E2);
  static const Color primaryPurple = Color(0xFF7B68EE);
  static const Color primaryPink = Color(0xFFE91E63);

  /// Accent color for highlights
  static const Color accent = Color(0xFF00D4FF);

  // ============================================================
  // BACKGROUND COLORS
  // ============================================================

  /// Main dark background
  static const Color backgroundDark = Color(0xFF0A0E14);

  /// Slightly lighter background for contrast
  static const Color backgroundMedium = Color(0xFF0D1B2A);

  /// Card and elevated surface background
  static const Color backgroundCard = Color(0xFF1B263B);

  /// Elevated elements background
  static const Color backgroundElevated = Color(0xFF243447);

  /// Input field background
  static const Color backgroundInput = Color(0xFF151F2E);

  // ============================================================
  // TEXT COLORS
  // ============================================================

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF6B7C93);
  static const Color textDisabled = Color(0xFF4A5568);

  // ============================================================
  // STATUS COLORS
  // ============================================================

  static const Color success = Color(0xFF00E676);
  static const Color successDark = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFFF9800);
  static const Color error = Color(0xFFFF5252);
  static const Color errorDark = Color(0xFFD32F2F);
  static const Color info = Color(0xFF40C4FF);
  static const Color infoDark = Color(0xFF00B0FF);

  // ============================================================
  // GRADIENTS
  // ============================================================

  /// Primary gradient for buttons and accents
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryPurple],
  );

  /// Extended gradient with pink accent
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryPurple, primaryPink],
  );

  /// Subtle gradient for backgrounds
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDark, backgroundMedium, backgroundDark],
    stops: [0.0, 0.5, 1.0],
  );

  /// Radial glow gradient for logo/icons
  static RadialGradient glowGradient(Color color) => RadialGradient(
    colors: [
      color.withValues(alpha: 0.3),
      color.withValues(alpha: 0.1),
      color.withValues(alpha: 0.0),
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  // ============================================================
  // SHADOWS
  // ============================================================

  static List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: primaryBlue.withValues(alpha: 0.4),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: primaryPurple.withValues(alpha: 0.2),
      blurRadius: 40,
      offset: const Offset(0, 16),
      spreadRadius: -8,
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.5),
      blurRadius: 30,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // ============================================================
  // BORDER RADIUS
  // ============================================================

  static const double radiusXS = 6.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 28.0;
  static const double radiusRound = 100.0;

  // Shorthand border radius
  static BorderRadius get borderRadiusS => BorderRadius.circular(radiusS);
  static BorderRadius get borderRadiusM => BorderRadius.circular(radiusM);
  static BorderRadius get borderRadiusL => BorderRadius.circular(radiusL);
  static BorderRadius get borderRadiusXL => BorderRadius.circular(radiusXL);

  // ============================================================
  // SPACING
  // ============================================================

  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  static const double spacingXXXL = 64.0;

  // ============================================================
  // TEXT STYLES
  // ============================================================

  // Display styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -1,
    height: 1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // Heading styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
    height: 1.35,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
    height: 1.4,
  );

  // Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMuted,
    letterSpacing: 0.4,
    height: 1.5,
  );

  // Label styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // Button text
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
    height: 1.2,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
    height: 1.2,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 1.5,
    height: 1.4,
  );

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      labelStyle: bodyMedium.copyWith(color: textMuted),
      hintStyle: bodyMedium.copyWith(color: textDisabled),
      errorStyle: bodySmall.copyWith(color: error),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: primaryBlue, size: 22)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: backgroundInput,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingM,
        vertical: spacingM,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: BorderSide(
          color: backgroundElevated.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(
          color: primaryBlue,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(
          color: error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(
          color: error,
          width: 2,
        ),
      ),
    );
  }

  // ============================================================
  // THEME DATA
  // ============================================================

  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    primaryColor: primaryBlue,
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: primaryPurple,
      tertiary: primaryPink,
      surface: backgroundCard,
      error: error,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
      onSurface: textPrimary,
      onError: textPrimary,
    ),

    // AppBar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textSecondary),
      titleTextStyle: headingSmall,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    // Card Theme
    cardTheme: CardTheme(
      color: backgroundCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusL),
      ),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        textStyle: buttonLarge,
      ),
    ),

    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
        textStyle: buttonMedium,
      ),
    ),

    // Outlined Button Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(
          color: primaryBlue.withValues(alpha: 0.5),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        textStyle: buttonLarge,
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundInput,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingM,
        vertical: spacingM,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: BorderSide(
          color: backgroundElevated.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(
          color: primaryBlue,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(
          color: error,
          width: 1,
        ),
      ),
      labelStyle: bodyMedium.copyWith(color: textMuted),
      hintStyle: bodyMedium.copyWith(color: textDisabled),
    ),

    // Snackbar Theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: backgroundElevated,
      contentTextStyle: bodyMedium.copyWith(color: textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusM),
      ),
    ),

    // Dialog Theme
    dialogTheme: DialogTheme(
      backgroundColor: backgroundCard,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXL),
      ),
      titleTextStyle: headingSmall,
      contentTextStyle: bodyMedium,
    ),

    // Bottom Sheet Theme
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radiusXL),
        ),
      ),
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: backgroundElevated.withValues(alpha: 0.5),
      thickness: 1,
      space: spacingM,
    ),

    // Progress Indicator Theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryBlue,
      linearTrackColor: backgroundElevated,
    ),

    // Icon Theme
    iconTheme: const IconThemeData(
      color: textSecondary,
      size: 24,
    ),
  );
}

// ============================================================
// ELITE UI COMPONENTS
// ============================================================

/// Elite gradient button with glow effect
class EliteButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double height;

  const EliteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return _buildOutlinedButton();
    }
    return _buildGradientButton();
  }

  Widget _buildGradientButton() {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed != null && !isLoading
            ? AppTheme.primaryGradient
            : null,
        color: onPressed == null || isLoading
            ? AppTheme.backgroundElevated
            : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: onPressed != null && !isLoading
            ? AppTheme.primaryShadow
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Text(label, style: AppTheme.buttonLarge),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton() {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.4),
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
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryBlue,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: AppTheme.textPrimary, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: AppTheme.buttonLarge.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Elite text field with consistent styling
class EliteTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;

  const EliteTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      enabled: enabled,
      inputFormatters: inputFormatters,
      style: AppTheme.bodyLarge,
      decoration: AppTheme.inputDecoration(
        label: label,
        hint: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Elite card with glass morphism effect
class EliteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final bool showBorder;
  final Gradient? gradient;

  const EliteCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.showBorder = true,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppTheme.backgroundCard : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: showBorder
            ? Border.all(
                color: AppTheme.backgroundElevated.withValues(alpha: 0.5),
                width: 1,
              )
            : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spacingM),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Elite gradient text
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient? gradient;

  const GradientText({
    super.key,
    required this.text,
    this.style,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          (gradient ?? AppTheme.accentGradient).createShader(bounds),
      child: Text(
        text,
        style: (style ?? AppTheme.displayMedium).copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Elite logo with glow effect
class EliteLogo extends StatelessWidget {
  final double size;
  final bool showGlow;

  const EliteLogo({
    super.key,
    this.size = 100,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(size * 0.24),
              ),
              child: Center(
                child: Text(
                  'H',
                  style: TextStyle(
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Scaffold wrapper with consistent background
class EliteScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool useGradientBackground;

  const EliteScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.useGradientBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: useGradientBackground
            ? const BoxDecoration(gradient: AppTheme.backgroundGradient)
            : const BoxDecoration(color: AppTheme.backgroundDark),
        child: body,
      ),
    );
  }
}

/// Tab switcher with gradient active state
class EliteTabSwitcher extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final void Function(int) onTabSelected;

  const EliteTabSwitcher({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: AppTheme.backgroundElevated.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL - 2),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTheme.buttonMedium.copyWith(
                    color: isSelected
                        ? AppTheme.textPrimary
                        : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Info banner with icon
class EliteInfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? iconColor;

  const EliteInfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundElevated.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.backgroundElevated.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryBlue).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
