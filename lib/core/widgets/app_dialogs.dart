import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Utility class for showing consistent dialogs across the app
class AppDialogs {
  AppDialogs._();

  /// Show a confirmation dialog
  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor ?? (isDangerous ? AppTheme.error : AppTheme.primaryBlue),
        icon: icon ?? (isDangerous ? Icons.warning_amber_rounded : Icons.help_outline),
        isDangerous: isDangerous,
      ),
    );
    return result ?? false;
  }

  /// Show a delete confirmation dialog
  static Future<bool> showDeleteConfirmation(
    BuildContext context, {
    required String itemName,
    String? additionalMessage,
  }) {
    return showConfirmation(
      context,
      title: 'Delete $itemName?',
      message: additionalMessage ?? 'This action cannot be undone.',
      confirmText: 'Delete',
      icon: Icons.delete_forever,
      isDangerous: true,
    );
  }

  /// Show an info dialog
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    IconData? icon,
  }) {
    return showDialog(
      context: context,
      builder: (context) => _InfoDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        icon: icon ?? Icons.info_outline,
      ),
    );
  }

  /// Show a loading dialog
  static Future<void> showLoading(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LoadingDialog(message: message),
    );
  }

  /// Hide the current dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Show an input dialog
  static Future<String?> showInput(
    BuildContext context, {
    required String title,
    String? hintText,
    String? initialValue,
    String confirmText = 'Submit',
    String cancelText = 'Cancel',
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _InputDialog(
        title: title,
        hintText: hintText,
        initialValue: initialValue,
        confirmText: confirmText,
        cancelText: cancelText,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }
}

class _ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final IconData icon;
  final bool isDangerous;

  const _ConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.confirmColor,
    required this.icon,
    required this.isDangerous,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      title: Row(
        children: [
          Icon(
            icon,
            color: isDangerous ? AppTheme.error : AppTheme.primaryBlue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTheme.headingSmall,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: AppTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

class _InfoDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final IconData icon;

  const _InfoDialog({
    required this.title,
    required this.message,
    required this.buttonText,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      title: Row(
        children: [
          Icon(icon, color: AppTheme.info, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: AppTheme.headingSmall),
          ),
        ],
      ),
      content: Text(message, style: AppTheme.bodyMedium),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
          child: Text(buttonText),
        ),
      ],
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  final String message;

  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              message,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputDialog extends StatefulWidget {
  final String title;
  final String? hintText;
  final String? initialValue;
  final String confirmText;
  final String cancelText;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _InputDialog({
    required this.title,
    this.hintText,
    this.initialValue,
    required this.confirmText,
    required this.cancelText,
    required this.maxLines,
    required this.keyboardType,
    this.validator,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      title: Text(widget.title, style: AppTheme.headingSmall),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          style: AppTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTheme.bodyMedium,
            filled: true,
            fillColor: AppTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              borderSide: const BorderSide(color: AppTheme.primaryBlue),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.cancelText,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? true) {
              Navigator.pop(context, _controller.text);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
