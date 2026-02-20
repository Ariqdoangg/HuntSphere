import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/checkpoint_model.dart';
import 'package:huntsphere/features/shared/models/task_model.dart';
import 'package:huntsphere/services/supabase_service.dart';
import 'add_checkpoint_dialog.dart';
import 'task_management_screen.dart';

class CheckpointSetupScreen extends StatefulWidget {
  final ActivityModel activity;

  const CheckpointSetupScreen({
    super.key,
    required this.activity,
  });

  @override
  State<CheckpointSetupScreen> createState() => _CheckpointSetupScreenState();
}

class _CheckpointSetupScreenState extends State<CheckpointSetupScreen>
    with SingleTickerProviderStateMixin {
  List<CheckpointModel> _checkpoints = [];
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadCheckpoints();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckpoints() async {
    setState(() => _isLoading = true);
    try {
      final checkpoints =
          await SupabaseService.getCheckpoints(widget.activity.id!);
      setState(() {
        _checkpoints = checkpoints;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Error loading checkpoints: $e', isError: true);
      }
    }
  }

  Future<void> _showAddCheckpointDialog() async {
    HapticFeedback.lightImpact();
    final result = await showDialog<CheckpointModel>(
      context: context,
      builder: (context) => AddCheckpointDialog(
        activityId: widget.activity.id!,
        sequenceOrder: _checkpoints.length + 1,
      ),
    );

    if (result != null) {
      await _loadCheckpoints();
    }
  }

  Future<void> _deleteCheckpoint(CheckpointModel checkpoint) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Icon(Icons.delete_outline, color: AppTheme.error),
            ),
            const SizedBox(width: AppTheme.spacingM),
            const Expanded(
              child: Text('Delete Checkpoint?', style: AppTheme.headingSmall),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${checkpoint.name}"? This action cannot be undone.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          EliteButton(
            label: 'Delete',
            icon: Icons.delete,
            onPressed: () => Navigator.pop(context, true),
            width: 120,
            height: 44,
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.deleteCheckpoint(checkpoint.id!);
        await _loadCheckpoints();
        if (mounted) {
          _showSnackBar('Checkpoint deleted');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  Future<void> _finishSetup() async {
    if (_checkpoints.isEmpty) {
      _showSnackBar('Please add at least one checkpoint', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    _showSnackBar('Setup complete! Join Code: ${widget.activity.joinCode}');
    Navigator.pop(context);
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
        title: const Text('Setup Checkpoints'),
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
        actions: [
          if (_checkpoints.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingM),
              child: TextButton.icon(
                onPressed: _finishSetup,
                icon: const Icon(Icons.check_circle, color: AppTheme.success),
                label: const Text(
                  'Finish',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Activity Info Card
            _buildActivityHeader(),

            // Checkpoints List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : _checkpoints.isEmpty
                      ? _buildEmptyState()
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildCheckpointsList(),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildActivityHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppTheme.spacingM),
      child: EliteCard(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.15),
            AppTheme.primaryPurple.withValues(alpha: 0.1),
            AppTheme.backgroundCard,
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              widget.activity.name,
              style: AppTheme.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.vpn_key_rounded,
                    color: AppTheme.accent,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    widget.activity.joinCode,
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.accent,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Icon(
                Icons.add_location_alt_outlined,
                size: 64,
                color: AppTheme.textMuted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No checkpoints yet',
              style: AppTheme.headingSmall.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Tap the button below to add your first checkpoint',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textDisabled),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckpointsList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      itemCount: _checkpoints.length,
      onReorder: (oldIndex, newIndex) {
        // TODO: Implement reordering
      },
      itemBuilder: (context, index) {
        final checkpoint = _checkpoints[index];
        return _CheckpointCard(
          key: ValueKey(checkpoint.id),
          checkpoint: checkpoint,
          index: index,
          onDelete: () => _deleteCheckpoint(checkpoint),
        );
      },
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.primaryShadow,
      ),
      child: FloatingActionButton.extended(
        onPressed: _showAddCheckpointDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_location, color: Colors.white),
        label: const Text(
          'Add Checkpoint',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CheckpointCard extends StatelessWidget {
  final CheckpointModel checkpoint;
  final int index;
  final VoidCallback onDelete;

  const _CheckpointCard({
    super.key,
    required this.checkpoint,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: EliteCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(AppTheme.spacingM),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: AppTheme.headingSmall.copyWith(color: Colors.white),
                  ),
                ),
              ),
              title: Text(
                checkpoint.name,
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingS),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 14,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${checkpoint.latitude.toStringAsFixed(6)}, ${checkpoint.longitude.toStringAsFixed(6)}',
                            style: AppTheme.bodySmall.copyWith(
                              fontFamily: 'monospace',
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildTag(
                          Icons.circle_outlined,
                          '${checkpoint.radiusMeters}m',
                          AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        _buildTag(
                          Icons.star_rounded,
                          '${checkpoint.arrivalPoints} pts',
                          AppTheme.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconButton(
                    Icons.add_task,
                    AppTheme.accent,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TaskManagementScreen(checkpoint: checkpoint),
                        ),
                      );
                    },
                    'Manage Tasks',
                  ),
                  const SizedBox(width: 4),
                  _buildIconButton(
                    Icons.delete_outline,
                    AppTheme.error,
                    onDelete,
                    'Delete',
                  ),
                ],
              ),
            ),
            // Tasks count
            FutureBuilder<List<TaskModel>>(
              future: SupabaseService.getTasks(checkpoint.id!),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppTheme.radiusL),
                        bottomRight: Radius.circular(AppTheme.radiusL),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.task_alt,
                          size: 14,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${snapshot.data!.length} task(s) configured',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
