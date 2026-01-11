import 'package:flutter/material.dart';
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

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  List<TaskModel> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await SupabaseService.getTasks(widget.checkpoint.id!);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e')),
        );
      }
    }
  }

  Future<void> _showAddTaskDialog() async {
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
    showDialog(
      context: context,
      builder: (context) => _TaskDetailsDialog(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks: ${widget.checkpoint.name}'),
        backgroundColor: const Color(0xFF0A1628),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF00D9FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.checkpoint.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.checkpoint.latitude.toStringAsFixed(6)}, ${widget.checkpoint.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt,
                              size: 80,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first task',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          return _TaskCard(
                            task: _tasks[index],
                            onTap: () => _showTaskDetails(_tasks[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: const Color(0xFF00D9FF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Task',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
        return Icons.photo_camera;
      case 'video':
        return Icons.videocam;
      case 'quiz':
        return Icons.quiz;
      case 'qr_code':
        return Icons.qr_code;
      default:
        return Icons.task;
    }
  }

  Color _getTaskColor() {
    switch (task.taskType) {
      case 'photo':
        return Colors.purple;
      case 'video':
        return Colors.red;
      case 'quiz':
        return Colors.green;
      case 'qr_code':
        return Colors.orange;
      default:
        return const Color(0xFF00D9FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1A2332),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getTaskColor().withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _getTaskColor(),
                foregroundColor: Colors.white,
                radius: 24,
                child: Icon(_getTaskIcon(), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (task.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getTaskColor().withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.taskType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getTaskColor(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${task.points} pts',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
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
        return Colors.purple;
      case 'video':
        return Colors.red;
      case 'quiz':
        return Colors.green;
      case 'qr_code':
        return Colors.orange;
      default:
        return const Color(0xFF00D9FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A1628),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getTaskColor(),
                    foregroundColor: Colors.white,
                    child: Icon(_getTaskIcon()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getTaskColor().withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${task.taskType.toUpperCase()} • ${task.points} pts',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getTaskColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (task.description != null) ...[
                _InfoSection(
                  title: 'Description',
                  child: Text(
                    task.description!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (task.taskType == 'quiz') ..._buildQuizDetails(),
              if (task.taskType == 'qr_code') ..._buildQRDetails(),
              if (task.taskType == 'photo' || task.taskType == 'video') ..._buildMediaDetails(),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTaskIcon() {
    switch (task.taskType) {
      case 'photo':
        return Icons.photo_camera;
      case 'video':
        return Icons.videocam;
      case 'quiz':
        return Icons.quiz;
      case 'qr_code':
        return Icons.qr_code;
      default:
        return Icons.task;
    }
  }

  List<Widget> _buildQuizDetails() {
    return [
      _InfoSection(
        title: 'Quiz Question',
        child: Text(
          task.quizQuestion ?? 'No question',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _InfoSection(
        title: 'Answer Options',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.quizOptions != null)
              ...task.quizOptions!.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isCorrect = option == task.quizCorrectAnswer;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect 
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect ? Colors.green : Colors.white24,
                      width: isCorrect ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isCorrect ? Colors.green : Colors.white24,
                        child: Text(
                          '${String.fromCharCode(65 + index)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                            color: isCorrect ? Colors.green : Colors.white,
                          ),
                        ),
                      ),
                      if (isCorrect)
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: task.qrCodeValue ?? '',
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Value: ${task.qrCodeValue}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '💡 Participants need to scan this exact QR code',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildMediaDetails() {
    return [
      _InfoSection(
        title: 'Submission Type',
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: task.taskType == 'photo' 
                ? Colors.purple.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                task.taskType == 'photo' ? Icons.photo_camera : Icons.videocam,
                color: task.taskType == 'photo' ? Colors.purple : Colors.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.taskType == 'photo' ? 'Photo Required' : 'Video Required',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: task.taskType == 'photo' ? Colors.purple : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Requires facilitator approval',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_outline, color: Colors.green),
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

  const _InfoSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
