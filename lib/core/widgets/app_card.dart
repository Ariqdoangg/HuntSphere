import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A styled card widget with consistent styling across the app
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final double? borderRadius;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.boxShadow,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusL),
        boxShadow: boxShadow ?? AppTheme.cardShadow,
        border: border,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusL),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spacingM),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Creates a card with a gradient border
  factory AppCard.gradient({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: padding,
      margin: margin,
      onTap: onTap,
      border: Border.all(
        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
        width: 1,
      ),
      child: child,
    );
  }

  /// Creates a card with elevated shadow
  factory AppCard.elevated({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: padding,
      margin: margin,
      onTap: onTap,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      child: child,
    );
  }
}

/// A card specifically designed for activity items
class ActivityCard extends StatelessWidget {
  final String name;
  final String joinCode;
  final String status;
  final int? participantCount;
  final int? checkpointCount;
  final VoidCallback? onTap;
  final VoidCallback? onManage;
  final VoidCallback? onDelete;

  const ActivityCard({
    super.key,
    required this.name,
    required this.joinCode,
    required this.status,
    this.participantCount,
    this.checkpointCount,
    this.onTap,
    this.onManage,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppTheme.headingSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.key,
                label: joinCode,
                color: AppTheme.primaryBlue,
              ),
              if (participantCount != null) ...[
                const SizedBox(width: AppTheme.spacingS),
                _buildInfoChip(
                  icon: Icons.people,
                  label: '$participantCount',
                  color: AppTheme.primaryPurple,
                ),
              ],
              if (checkpointCount != null) ...[
                const SizedBox(width: AppTheme.spacingS),
                _buildInfoChip(
                  icon: Icons.location_on,
                  label: '$checkpointCount',
                  color: AppTheme.primaryPink,
                ),
              ],
            ],
          ),
          if (onManage != null || onDelete != null) ...[
            const SizedBox(height: AppTheme.spacingM),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onManage != null)
                  TextButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Manage'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                    ),
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: AppTheme.error,
                    iconSize: 20,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'active':
        color = AppTheme.success;
        label = 'Active';
        break;
      case 'completed':
        color = AppTheme.info;
        label = 'Completed';
        break;
      case 'setup':
      default:
        color = AppTheme.warning;
        label = 'Setup';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
