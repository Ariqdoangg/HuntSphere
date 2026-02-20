import 'package:flutter/material.dart';

/// Accessibility utilities and semantic wrapper widgets for HuntSphere
/// These widgets help make the app more accessible to users with disabilities

/// A button with proper semantics for screen readers
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? semanticHint;
  final bool isEnabled;

  const AccessibleButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.semanticHint,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: isEnabled && onPressed != null,
      label: semanticLabel,
      hint: semanticHint,
      child: ExcludeSemantics(
        child: child,
      ),
    );
  }
}

/// An image with accessibility description
class AccessibleImage extends StatelessWidget {
  final ImageProvider image;
  final String semanticLabel;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const AccessibleImage({
    super.key,
    required this.image,
    required this.semanticLabel,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: Image(
        image: image,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

/// A card with proper semantic grouping
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double borderRadius;

  const AccessibleCard({
    super.key,
    required this.child,
    this.semanticLabel,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: card,
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      child: card,
    );
  }
}

/// A text field with proper semantics
class AccessibleTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String labelText;
  final String? hintText;
  final String? semanticLabel;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;

  const AccessibleTextField({
    super.key,
    this.controller,
    required this.labelText,
    this.hintText,
    this.semanticLabel,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel ?? labelText,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFF0D1B2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4A90E2)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE53935)),
          ),
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

/// A header/section title with proper heading semantics
class AccessibleHeading extends StatelessWidget {
  final String text;
  final int level; // 1-6, like HTML h1-h6
  final TextStyle? style;
  final TextAlign? textAlign;

  const AccessibleHeading({
    super.key,
    required this.text,
    this.level = 1,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: style ?? _getDefaultStyle(),
        textAlign: textAlign,
      ),
    );
  }

  TextStyle _getDefaultStyle() {
    switch (level) {
      case 1:
        return const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        );
      case 2:
        return const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );
      case 3:
        return const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );
      case 4:
        return const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        );
      default:
        return const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        );
    }
  }
}

/// A status indicator with semantic announcement
class AccessibleStatus extends StatelessWidget {
  final String status;
  final Color color;
  final IconData? icon;
  final bool announceOnBuild;

  const AccessibleStatus({
    super.key,
    required this.status,
    required this.color,
    this.icon,
    this.announceOnBuild = false,
  });

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Status: $status',
      liveRegion: announceOnBuild,
      child: widget,
    );
  }
}

/// Extension to easily add semantics to any widget
extension SemanticExtensions on Widget {
  /// Wraps this widget with a semantic label
  Widget withSemanticLabel(String label) {
    return Semantics(
      label: label,
      child: this,
    );
  }

  /// Wraps this widget with button semantics
  Widget asSemanticButton(String label, {String? hint}) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: this,
    );
  }

  /// Marks this widget as a header
  Widget asSemanticHeader() {
    return Semantics(
      header: true,
      child: this,
    );
  }

  /// Excludes this widget from semantics tree
  Widget excludeFromSemantics() {
    return ExcludeSemantics(child: this);
  }
}
