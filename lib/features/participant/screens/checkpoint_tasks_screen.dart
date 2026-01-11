import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckpointTasksScreen extends StatefulWidget {
  final String checkpointId;
  final String checkpointName;
  final String teamId;

  const CheckpointTasksScreen({
    super.key,
    required this.checkpointId,
    required this.checkpointName,
    required this.teamId,
  });

  @override
  State<CheckpointTasksScreen> createState() => _CheckpointTasksScreenState();
}

class _CheckpointTasksScreenState extends State<CheckpointTasksScreen> {
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final response = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('checkpoint_id', widget.checkpointId);

      setState(() {
        tasks = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.checkpointName),
        backgroundColor: const Color(0xFF0A1628),
      ),
      backgroundColor: const Color(0xFF0A1628),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? const Center(
                  child: Text(
                    'No tasks at this checkpoint',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    IconData icon;
    Color color;
    
    switch (task['task_type']) {
      case 'photo':
        icon = Icons.camera_alt;
        color = Colors.blue;
        break;
      case 'quiz':
        icon = Icons.quiz;
        color = Colors.purple;
        break;
      case 'qr':
        icon = Icons.qr_code_scanner;
        color = Colors.green;
        break;
      default:
        icon = Icons.task;
        color = Colors.grey;
    }

    return Card(
      color: const Color(0xFF1A2332),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _openTask(task),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title'] ?? 'Task',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${task['points']} points',
                              style: const TextStyle(
                                color: Color(0xFF00D9FF),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
              if (task['description'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  task['description'],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
              if (task['is_required'] == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openTask(Map<String, dynamic> task) {
    final taskType = task['task_type'];
    
    if (taskType == 'photo') {
      Navigator.pushNamed(
        context,
        '/photo-task',
        arguments: {
          'task': task,
          'teamId': widget.teamId,
          'checkpointName': widget.checkpointName,
        },
      );
    } else if (taskType == 'quiz') {
      Navigator.pushNamed(
        context,
        '/quiz-task',
        arguments: {
          'task': task,
          'teamId': widget.teamId,
        },
      );
    } else if (taskType == 'qr') {
      Navigator.pushNamed(
        context,
        '/qr-task',
        arguments: {
          'task': task,
          'teamId': widget.teamId,
        },
      );
    }
  }
}
