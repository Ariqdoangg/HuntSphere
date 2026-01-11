import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/services/supabase_service.dart';
import 'activity_setup_screen.dart';
import 'checkpoint_setup_screen.dart';
import 'facilitator_lobby_screen.dart';

class FacilitatorDashboard extends StatefulWidget {
  const FacilitatorDashboard({super.key});

  @override
  State<FacilitatorDashboard> createState() => _FacilitatorDashboardState();
}

class _FacilitatorDashboardState extends State<FacilitatorDashboard> {
  List<ActivityModel> _activities = [];
  bool _isLoading = true;
  String _facilitatorName = '';

  @override
  void initState() {
    super.initState();
    _loadFacilitatorData();
  }

  Future<void> _loadFacilitatorData() async {
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      // Get facilitator name
      final facilData = await Supabase.instance.client
          .from('facilitators')
          .select('name')
          .eq('user_id', userId)
          .single();

      _facilitatorName = facilData['name'] ?? 'Facilitator';

      // Get all activities created by this facilitator
      final response = await Supabase.instance.client
          .from('activities')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      setState(() {
        _activities = (response as List)
            .map((json) => ActivityModel.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activities: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  void _createNewActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActivitySetupScreen(),
      ),
    ).then((_) => _loadFacilitatorData());
  }

  void _continueActivity(ActivityModel activity) {
    // Navigate to checkpoint setup to continue configuring
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckpointSetupScreen(activity: activity),
      ),
    ).then((_) => _loadFacilitatorData());
  }

  Future<void> _deleteActivity(ActivityModel activity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: Text(
            'Are you sure you want to delete "${activity.name}"? This cannot be undone.'),
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
        await Supabase.instance.client
            .from('activities')
            .delete()
            .eq('id', activity.id!);

        await _loadFacilitatorData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activity deleted'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $_facilitatorName'),
        backgroundColor: const Color(0xFF0A1628),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFacilitatorData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? _buildEmptyState()
              : _buildActivityList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewActivity,
        backgroundColor: const Color(0xFF00D9FF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Activity',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 100,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No Activities Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first activity to get started!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewActivity,
            icon: const Icon(Icons.add),
            label: const Text('Create Activity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        return _ActivityCard(
          activity: activity,
          onTap: () => _continueActivity(activity),
          onDelete: () => _deleteActivity(activity),
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ActivityCard({
    required this.activity,
    required this.onTap,
    required this.onDelete,
  });

  Color _getStatusColor() {
    switch (activity.status) {
      case 'setup':
        return Colors.orange;
      case 'lobby':
        return Colors.blue;
      case 'started':
      case 'active': // Add 'active' status
        return Colors.green;
      case 'finished':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  String _getStatusText() {
    switch (activity.status) {
      case 'setup':
        return 'In Setup';
      case 'lobby':
        return 'In Lobby';
      case 'started':
      case 'active': // Add 'active' status
        return 'Active';
      case 'finished':
        return 'Finished';
      default:
        return activity.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1A2332),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event,
                      color: Color(0xFF00D9FF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor().withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText().toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              // Info chips row
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.key,
                    label: activity.joinCode,
                    color: const Color(0xFF00D9FF),
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.timer,
                    label: '${activity.totalDurationMinutes} min',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: _formatDate(activity.createdAt),
                    color: Colors.purple,
                  ),
                ],
              ),

              // ✨ NEW: Action buttons row
              const SizedBox(height: 16),
              Row(
                children: [
                  // View Lobby Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FacilitatorLobbyScreen(
                              activity: activity,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.people, size: 18),
                      label: const Text(
                        'View Lobby',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D9FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Edit Checkpoints Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          onTap, // Uses existing onTap (goes to checkpoint setup)
                      icon: const Icon(Icons.edit_location, size: 18),
                      label: const Text(
                        'Edit Setup',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2332),
                        foregroundColor: const Color(0xFF00D9FF),
                        side: const BorderSide(
                          color: Color(0xFF00D9FF),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
