import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A consistent empty state widget for when there's no data to display
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              title,
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                subtitle!,
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Creates an empty state for activities
  factory AppEmptyState.activities({VoidCallback? onCreateActivity}) {
    return AppEmptyState(
      icon: Icons.explore_outlined,
      title: 'No Activities Yet',
      subtitle: 'Create your first activity to get started',
      actionLabel: onCreateActivity != null ? 'Create Activity' : null,
      onAction: onCreateActivity,
    );
  }

  /// Creates an empty state for checkpoints
  factory AppEmptyState.checkpoints({VoidCallback? onAddCheckpoint}) {
    return AppEmptyState(
      icon: Icons.location_on_outlined,
      title: 'No Checkpoints',
      subtitle: 'Add checkpoints to create your treasure hunt route',
      actionLabel: onAddCheckpoint != null ? 'Add Checkpoint' : null,
      onAction: onAddCheckpoint,
    );
  }

  /// Creates an empty state for tasks
  factory AppEmptyState.tasks({VoidCallback? onAddTask}) {
    return AppEmptyState(
      icon: Icons.assignment_outlined,
      title: 'No Tasks',
      subtitle: 'Add tasks to challenge your participants',
      actionLabel: onAddTask != null ? 'Add Task' : null,
      onAction: onAddTask,
    );
  }

  /// Creates an empty state for participants
  factory AppEmptyState.participants() {
    return const AppEmptyState(
      icon: Icons.people_outline,
      title: 'Waiting for Participants',
      subtitle: 'Share the join code to invite participants',
    );
  }

  /// Creates an empty state for search results
  factory AppEmptyState.searchResults() {
    return const AppEmptyState(
      icon: Icons.search_off,
      title: 'No Results Found',
      subtitle: 'Try adjusting your search criteria',
    );
  }
}
