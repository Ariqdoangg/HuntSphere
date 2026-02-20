import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingFacilitators = [];
  List<Map<String, dynamic>> _allFacilitators = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFacilitators();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilitators() async {
    setState(() => _isLoading = true);

    try {
      // Load pending facilitators
      final pendingResponse = await Supabase.instance.client
          .from('facilitators')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      // Load all facilitators
      final allResponse = await Supabase.instance.client
          .from('facilitators')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pendingFacilitators =
              List<Map<String, dynamic>>.from(pendingResponse);
          _allFacilitators = List<Map<String, dynamic>>.from(allResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading facilitators: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load facilitators');
      }
    }
  }

  Future<void> _approveFacilitator(Map<String, dynamic> facilitator) async {
    try {
      await Supabase.instance.client
          .from('facilitators')
          .update({
            'status': 'approved',
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', facilitator['id']);

      _showSuccess('${facilitator['name']} has been approved!');
      _loadFacilitators();
    } catch (e) {
      _showError('Failed to approve: $e');
    }
  }

  Future<void> _rejectFacilitator(Map<String, dynamic> facilitator) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text('Reject Registration?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reject ${facilitator['name']}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('facilitators')
            .update({'status': 'rejected'})
            .eq('id', facilitator['id']);

        _showSuccess('${facilitator['name']} has been rejected');
        _loadFacilitators();
      } catch (e) {
        _showError('Failed to reject: $e');
      }
    }
  }

  Future<void> _toggleAdmin(Map<String, dynamic> facilitator) async {
    final isCurrentlyAdmin = facilitator['is_admin'] == true;
    final action = isCurrentlyAdmin ? 'remove admin rights from' : 'make admin';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: Text(isCurrentlyAdmin ? 'Remove Admin?' : 'Make Admin?',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to $action ${facilitator['name']}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isCurrentlyAdmin ? Colors.orange : const Color(0xFF00D9FF),
            ),
            child: Text(isCurrentlyAdmin ? 'Remove Admin' : 'Make Admin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('facilitators')
            .update({'is_admin': !isCurrentlyAdmin})
            .eq('id', facilitator['id']);

        _showSuccess(isCurrentlyAdmin
            ? 'Admin rights removed from ${facilitator['name']}'
            : '${facilitator['name']} is now an admin');
        _loadFacilitators();
      } catch (e) {
        _showError('Failed to update: $e');
      }
    }
  }

  Future<void> _deleteFacilitator(Map<String, dynamic> facilitator) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text('Delete Facilitator?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${facilitator['name']}? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('facilitators')
            .delete()
            .eq('id', facilitator['id']);

        _showSuccess('${facilitator['name']} has been deleted');
        _loadFacilitators();
      } catch (e) {
        _showError('Failed to delete: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('Admin Management'),
        backgroundColor: const Color(0xFF0A1628),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00D9FF),
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: _pendingFacilitators.isNotEmpty,
                label: Text('${_pendingFacilitators.length}'),
                child: const Icon(Icons.pending_actions),
              ),
              text: 'Pending',
            ),
            const Tab(icon: Icon(Icons.people), text: 'All Facilitators'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFacilitators,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                _buildAllFacilitatorsTab(),
              ],
            ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingFacilitators.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'No Pending Requests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'All registration requests have been processed',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingFacilitators.length,
      itemBuilder: (context, index) {
        final facilitator = _pendingFacilitators[index];
        return _buildPendingCard(facilitator);
      },
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> facilitator) {
    final createdAt = facilitator['created_at'] != null
        ? DateFormat('MMM dd, yyyy HH:mm')
            .format(DateTime.parse(facilitator['created_at']).toLocal())
        : 'Unknown';

    return Card(
      color: const Color(0xFF1A2332),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  child: Text(
                    (facilitator['name'] as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facilitator['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        facilitator['email'] ?? '',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Registered: $createdAt',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectFacilitator(facilitator),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveFacilitator(facilitator),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllFacilitatorsTab() {
    if (_allFacilitators.isEmpty) {
      return const Center(
        child: Text(
          'No facilitators found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allFacilitators.length,
      itemBuilder: (context, index) {
        final facilitator = _allFacilitators[index];
        return _buildFacilitatorCard(facilitator);
      },
    );
  }

  Widget _buildFacilitatorCard(Map<String, dynamic> facilitator) {
    final status = facilitator['status'] ?? 'pending';
    final isAdmin = facilitator['is_admin'] == true;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCurrentUser = facilitator['user_id'] == currentUserId;

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      color: const Color(0xFF1A2332),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Text(
            (facilitator['name'] as String? ?? 'U')[0].toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                facilitator['name'] ?? 'Unknown',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Color(0xFF00D9FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              facilitator['email'] ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: isCurrentUser
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                color: const Color(0xFF1A2332),
                onSelected: (value) {
                  switch (value) {
                    case 'approve':
                      _approveFacilitator(facilitator);
                      break;
                    case 'reject':
                      _rejectFacilitator(facilitator);
                      break;
                    case 'toggle_admin':
                      _toggleAdmin(facilitator);
                      break;
                    case 'delete':
                      _deleteFacilitator(facilitator);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (status == 'pending') ...[
                    const PopupMenuItem(
                      value: 'approve',
                      child: Row(
                        children: [
                          Icon(Icons.check, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Approve',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reject',
                      child: Row(
                        children: [
                          Icon(Icons.close, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Reject', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                  if (status == 'approved')
                    PopupMenuItem(
                      value: 'toggle_admin',
                      child: Row(
                        children: [
                          Icon(
                            isAdmin ? Icons.remove_moderator : Icons.admin_panel_settings,
                            color: isAdmin ? Colors.orange : const Color(0xFF00D9FF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isAdmin ? 'Remove Admin' : 'Make Admin',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
