import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _CheckpointSetupScreenState extends State<CheckpointSetupScreen> {
  List<CheckpointModel> _checkpoints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCheckpoints();
  }

  Future<void> _loadCheckpoints() async {
    setState(() => _isLoading = true);
    try {
      final checkpoints = await SupabaseService.getCheckpoints(widget.activity.id!);
      setState(() {
        _checkpoints = checkpoints;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading checkpoints: $e')),
        );
      }
    }
  }

  Future<void> _showAddCheckpointDialog() async {
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
        title: const Text('Delete Checkpoint?'),
        content: Text('Are you sure you want to delete "${checkpoint.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.deleteCheckpoint(checkpoint.id!);
        await _loadCheckpoints();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Checkpoint deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _finishSetup() async {
    if (_checkpoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one checkpoint'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Setup complete! Join Code: ${widget.activity.joinCode}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Checkpoints'),
        backgroundColor: const Color(0xFF0A1628),
        actions: [
          if (_checkpoints.isNotEmpty)
            TextButton.icon(
              onPressed: _finishSetup,
              icon: const Icon(Icons.check, color: Color(0xFF00D9FF)),
              label: const Text(
                'Finish Setup',
                style: TextStyle(color: Color(0xFF00D9FF)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D9FF).withValues(alpha: 0.2),
                  const Color(0xFF0A1628),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00D9FF).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.location_on, size: 48, color: Color(0xFF00D9FF)),
                const SizedBox(height: 12),
                Text(
                  widget.activity.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Join Code: ${widget.activity.joinCode}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D9FF),
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _checkpoints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_location_alt_outlined,
                              size: 80,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No checkpoints yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to add your first checkpoint',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _checkpoints.length,
                        onReorder: (oldIndex, newIndex) {
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
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCheckpointDialog,
        backgroundColor: const Color(0xFF00D9FF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_location),
        label: const Text(
          'Add Checkpoint',
          style: TextStyle(fontWeight: FontWeight.bold),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1A2332),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF00D9FF).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              checkpoint.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 14, color: Color(0xFF00D9FF)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${checkpoint.latitude.toStringAsFixed(6)}, ${checkpoint.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.circle_outlined, size: 14, color: Color(0xFF00D9FF)),
                      const SizedBox(width: 4),
                      Text(
                        'Radius: ${checkpoint.radiusMeters}m',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${checkpoint.arrivalPoints} pts',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_task, color: Color(0xFF00D9FF)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskManagementScreen(
                          checkpoint: checkpoint,
                        ),
                      ),
                    );
                  },
                  tooltip: 'Manage Tasks',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          FutureBuilder<List<TaskModel>>(
            future: SupabaseService.getTasks(checkpoint.id!),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    '${snapshot.data!.length} task(s) configured',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00D9FF),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
