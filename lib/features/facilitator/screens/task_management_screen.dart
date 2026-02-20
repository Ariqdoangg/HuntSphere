import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/shared/models/checkpoint_model.dart';
import 'package:huntsphere/features/shared/models/task_model.dart';
import 'package:huntsphere/services/supabase_service.dart';
import 'add_task_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TaskManagementScreen extends StatefulWidget {
  final CheckpointModel checkpoint;

  const TaskManagementScreen({
    super.key,
    required this.checkpoint,
  });

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen>
    with SingleTickerProviderStateMixin {
  List<TaskModel> _tasks = [];
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

    _loadTasks();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await SupabaseService.getTasks(widget.checkpoint.id!);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading tasks: $e')),
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

  Future<void> _showAddTaskDialog() async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<TaskModel>(
      context: context,
      builder: (context) => AddTaskDialog(
        checkpointId: widget.checkpoint.id!,
      ),
    );

    if (result != null) {
      await _loadTasks();
    }
  }

  void _showTaskDetails(TaskModel task) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => _TaskDetailsDialog(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      appBar: AppBar(
        title: Text('Tasks: ${widget.checkpoint.name}'),
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
      body: Column(
        children: [
          // Checkpoint Info Card
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: EliteCard(
              showBorder: true,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accent.withValues(alpha: 0.15),
                  AppTheme.primaryPurple.withValues(alpha: 0.05),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.checkpoint.name,
                              style: AppTheme.headingSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.checkpoint.latitude.toStringAsFixed(6)}, ${widget.checkpoint.longitude.toStringAsFixed(6)}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Task Count Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusRound),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.task_alt_rounded,
                              color: AppTheme.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_tasks.length}',
                              style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tasks List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  )
                : _tasks.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingM),
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 300 + index * 100),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: _TaskCard(
                                task: _tasks[index],
                                onTap: () => _showTaskDetails(_tasks[index]),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusRound),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddTaskDialog,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Task',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.textMuted.withValues(alpha: 0.1),
                  AppTheme.textMuted.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No tasks yet',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Tap + to add your first task',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  IconData _getTaskIcon() {
    switch (task.taskType) {
      case 'photo':
        return Icons.photo_camera_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      case 'qr_code':
        return Icons.qr_code_rounded;
      default:
        return Icons.task_rounded;
    }
  }

  Color _getTaskColor() {
    switch (task.taskType) {
      case 'photo':
        return AppTheme.primaryPurple;
      case 'video':
        return AppTheme.error;
      case 'quiz':
        return AppTheme.success;
      case 'qr_code':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskColor = _getTaskColor();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: taskColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: taskColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                // Task Type Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        taskColor,
                        taskColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: taskColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(_getTaskIcon(), size: 28, color: Colors.white),
                ),
                const SizedBox(width: AppTheme.spacingM),

                // Task Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (task.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppTheme.spacingS),
                      Row(
                        children: [
                          // Task Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: taskColor.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusS),
                            ),
                            child: Text(
                              task.taskType.toUpperCase().replaceAll('_', ' '),
                              style: AppTheme.labelSmall.copyWith(
                                color: taskColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          // Points Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusS),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: AppTheme.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${task.points} pts',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskDetailsDialog extends StatelessWidget {
  final TaskModel task;

  const _TaskDetailsDialog({required this.task});

  Color _getTaskColor() {
    switch (task.taskType) {
      case 'photo':
        return AppTheme.primaryPurple;
      case 'video':
        return AppTheme.error;
      case 'quiz':
        return AppTheme.success;
      case 'qr_code':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }

  IconData _getTaskIcon() {
    switch (task.taskType) {
      case 'photo':
        return Icons.photo_camera_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      case 'qr_code':
        return Icons.qr_code_rounded;
      default:
        return Icons.task_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskColor = _getTaskColor();

    return Dialog(
      backgroundColor: AppTheme.backgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: taskColor.withValues(alpha: 0.3),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          taskColor,
                          taskColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child:
                        Icon(_getTaskIcon(), color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AppTheme.headingSmall,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: taskColor.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusS),
                          ),
                          child: Text(
                            '${task.taskType.toUpperCase().replaceAll('_', ' ')} • ${task.points} pts',
                            style: AppTheme.labelSmall.copyWith(
                              color: taskColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: const Icon(Icons.close, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),

              if (task.description != null) ...[
                _InfoSection(
                  title: 'Description',
                  color: taskColor,
                  child: Text(
                    task.description!,
                    style: AppTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
              ],

              if (task.taskType == 'quiz') ..._buildQuizDetails(taskColor),
              if (task.taskType == 'qr_code') ..._buildQRDetails(),
              if (task.taskType == 'photo' || task.taskType == 'video')
                ..._buildMediaDetails(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuizDetails(Color color) {
    return [
      _InfoSection(
        title: 'Quiz Question',
        color: color,
        child: Text(
          task.quizQuestion ?? 'No question',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.success,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: AppTheme.spacingM),
      _InfoSection(
        title: 'Answer Options',
        color: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.quizOptions != null)
              ...task.quizOptions!.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isCorrect = option == task.quizCorrectAnswer;
                return Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    gradient: isCorrect
                        ? LinearGradient(
                            colors: [
                              AppTheme.success.withValues(alpha: 0.2),
                              AppTheme.success.withValues(alpha: 0.1),
                            ],
                          )
                        : null,
                    color: isCorrect
                        ? null
                        : AppTheme.backgroundCard.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: isCorrect
                          ? AppTheme.success
                          : AppTheme.textMuted.withValues(alpha: 0.3),
                      width: isCorrect ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? AppTheme.success
                              : AppTheme.backgroundElevated,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusRound),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCorrect
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Text(
                          option,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight:
                                isCorrect ? FontWeight.bold : FontWeight.normal,
                            color: isCorrect
                                ? AppTheme.success
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (isCorrect)
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: 20),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildQRDetails() {
    return [
      _InfoSection(
        title: 'QR Code',
        color: AppTheme.warning,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warning.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: task.qrCodeValue ?? '',
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.warning.withValues(alpha: 0.2),
                    AppTheme.warning.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_rounded,
                      color: AppTheme.warning, size: 20),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'Value: ${task.qrCodeValue}',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            const EliteInfoBanner(
              message: 'Participants need to scan this exact QR code',
              icon: Icons.lightbulb_outline_rounded,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildMediaDetails() {
    final isPhoto = task.taskType == 'photo';
    final color = isPhoto ? AppTheme.primaryPurple : AppTheme.error;

    return [
      _InfoSection(
        title: 'Submission Type',
        color: color,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Icon(
                  isPhoto ? Icons.photo_camera_rounded : Icons.videocam_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPhoto ? 'Photo Required' : 'Video Required',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requires facilitator approval',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppTheme.success,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color color;

  const _InfoSection({
    required this.title,
    required this.child,
    this.color = AppTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              title.toUpperCase(),
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        child,
      ],
    );
  }
}
