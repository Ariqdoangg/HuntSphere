import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  List<Map<String, dynamic>> _pendingFacilitators = [];
  List<Map<String, dynamic>> _allFacilitators = [];
  bool _isLoading = true;
  bool _hasAccess = false;
  int _totalFacilitators = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _adminCount = 0;
  String _searchQuery = '';
  String _activitySearchQuery = '';
  String _selectedActivityOwnerId = 'all';
  List<Map<String, dynamic>> _allActivities = [];
  int _totalActivities = 0;
  int _setupActivities = 0;
  int _activeActivities = 0;
  int _completedActivities = 0;
  int _clientsWithActivities = 0;
  int _clientsWithoutActivities = 0;
  DateTime? _lastSyncedAt;

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  // ─── DATA ────────────────────────────────────────────────────────────────

  Future<void> _verifyAccess() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic>? row;
      try {
        row = await Supabase.instance.client
            .from('facilitators')
            .select('is_admin, role')
            .eq('user_id', user.id)
            .maybeSingle();
      } on PostgrestException catch (e) {
        final missingRoleColumn = e.message.toLowerCase().contains('role') ||
            e.code == '42703' ||
            e.code == 'PGRST204';
        if (!missingRoleColumn) rethrow;

        row = await Supabase.instance.client
            .from('facilitators')
            .select('is_admin')
            .eq('user_id', user.id)
            .maybeSingle();
      }

      if (row == null) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      // TODO: migrate fully to role-based system and remove is_admin
      final role = (row['role'] as String?) ??
          (row['is_admin'] == true ? 'super_admin' : 'admin');

      if (role == 'super_admin') {
        setState(() => _hasAccess = true);
        _loadFacilitators();
      } else {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Access check failed: $e');
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFacilitators() async {
    setState(() => _isLoading = true);

    List pendingResponse = [];
    List allResponse = [];
    List activitiesResponse = [];

    try {
      pendingResponse = await Supabase.instance.client
          .from('facilitators')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
    } on PostgrestException catch (e) {
      debugPrint('[RLS?] facilitators(pending) - '
          'code: ${e.code}, msg: ${e.message}');
    } catch (e) {
      debugPrint('facilitators(pending) unexpected error: $e');
    }

    try {
      allResponse = await Supabase.instance.client
          .from('facilitators')
          .select()
          .order('created_at', ascending: false);
    } on PostgrestException catch (e) {
      debugPrint('[RLS?] facilitators(all) - '
          'code: ${e.code}, msg: ${e.message}');
    } catch (e) {
      debugPrint('facilitators(all) unexpected error: $e');
    }

    try {
      activitiesResponse = await Supabase.instance.client
          .from('activities')
          .select(
              'id, name, join_code, status, total_duration_minutes, created_at, created_by, facilitators(name)')
          .order('created_at', ascending: false);
    } on PostgrestException catch (e) {
      debugPrint('[RLS?] activities - code: ${e.code}, msg: ${e.message}');
    } catch (e) {
      debugPrint('activities unexpected error: $e');
    }

    if (mounted) {
      final all = List<Map<String, dynamic>>.from(allResponse);
      final activities = List<Map<String, dynamic>>.from(activitiesResponse);
      setState(() {
        _pendingFacilitators = List<Map<String, dynamic>>.from(pendingResponse);
        _allFacilitators = all;
        _totalFacilitators = all.length;
        _approvedCount = all.where((f) => f['status'] == 'approved').length;
        _rejectedCount = all.where((f) => f['status'] == 'rejected').length;
        _adminCount = all.where((f) => f['is_admin'] == true).length;
        _allActivities = activities;
        _totalActivities = activities.length;
        _setupActivities = activities.where((a) {
          final status = a['status'] ?? '';
          return status != 'started' &&
              status != 'active' &&
              status != 'in_progress' &&
              status != 'completed';
        }).length;
        _activeActivities = activities.where((a) {
          final status = a['status'] ?? '';
          return status == 'started' ||
              status == 'active' ||
              status == 'in_progress';
        }).length;
        _completedActivities =
            activities.where((a) => a['status'] == 'completed').length;
        final ownerIdsWithActivities =
            activities.map((a) => a['created_by']?.toString()).toSet();
        final approvedClients = all.where((f) => f['status'] == 'approved');
        _clientsWithActivities = approvedClients
            .where((f) => ownerIdsWithActivities.contains(f['user_id']))
            .length;
        _clientsWithoutActivities =
            approvedClients.length - _clientsWithActivities;
        _lastSyncedAt = DateTime.now();
        _isLoading = false;
      });
    }
  }

  Future<void> _approveFacilitator(Map<String, dynamic> facilitator) async {
    try {
      await Supabase.instance.client.from('facilitators').update({
        'status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', facilitator['id']);
      _showSuccess('${facilitator['name']} has been approved!');
      _loadFacilitators();
    } catch (e) {
      _showError('Failed to approve: $e');
    }
  }

  Future<void> _rejectFacilitator(Map<String, dynamic> facilitator) async {
    final confirm = await _confirmDialog(
      title: 'Reject Registration?',
      body: 'Are you sure you want to reject ${facilitator['name']}?',
      confirmLabel: 'Reject',
      confirmColor: AppTheme.error,
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('facilitators')
            .update({'status': 'rejected'}).eq('id', facilitator['id']);
        _showSuccess('${facilitator['name']} has been rejected');
        _loadFacilitators();
      } catch (e) {
        _showError('Failed to reject: $e');
      }
    }
  }

  Future<void> _toggleAdmin(Map<String, dynamic> facilitator) async {
    final isCurrentlyAdmin = facilitator['is_admin'] == true;
    final confirm = await _confirmDialog(
      title: isCurrentlyAdmin ? 'Remove Admin?' : 'Make Admin?',
      body:
          'Are you sure you want to ${isCurrentlyAdmin ? 'remove admin rights from' : 'make admin'} ${facilitator['name']}?',
      confirmLabel: isCurrentlyAdmin ? 'Remove Admin' : 'Make Admin',
      confirmColor: isCurrentlyAdmin ? AppTheme.warning : AppTheme.accent,
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('facilitators').update(
            {'is_admin': !isCurrentlyAdmin}).eq('id', facilitator['id']);
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
    final confirm = await _confirmDialog(
      title: 'Delete Facilitator?',
      body:
          'Are you sure you want to delete ${facilitator['name']}? This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.error,
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

  Future<void> _deleteActivity(String activityId) async {
    final confirm = await _confirmDialog(
      title: 'Delete Activity?',
      body: 'This will permanently delete the activity and all its data.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.error,
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('activities')
            .delete()
            .eq('id', activityId);
        _showSuccess('Activity deleted');
        _loadFacilitators();
      } catch (e) {
        _showError('Failed to delete activity: $e');
      }
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusXL),
        title: Text(title, style: AppTheme.headingSmall),
        content: Text(body, style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style:
                    AppTheme.buttonMedium.copyWith(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusM),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusM),
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusM),
    ));
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && !_hasAccess) {
      return _buildAccessRestricted();
    }

    return EliteScaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.spacingXXL),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildKPIRow(),
                              const SizedBox(height: AppTheme.spacingL),
                              _buildOperationalSummary(),
                              const SizedBox(height: AppTheme.spacingL),
                              _buildPendingSection(),
                              const SizedBox(height: AppTheme.spacingL),
                              _buildFacilitatorsSection(),
                              const SizedBox(height: AppTheme.spacingL),
                              _buildActivitiesSection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── ACCESS RESTRICTED ───────────────────────────────────────────────────

  Widget _buildAccessRestricted() {
    return EliteScaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXL),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: AppTheme.error, size: 56),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text('Access Restricted', style: AppTheme.headingMedium),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'You do not have permission to view this page.',
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXL),
                EliteButton(
                  label: 'Go Back',
                  icon: Icons.arrow_back_rounded,
                  isOutlined: true,
                  width: 160,
                  height: 48,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final lastSynced = _lastSyncedAt == null
        ? 'Not synced yet'
        : 'Synced ${DateFormat('HH:mm').format(_lastSyncedAt!)}';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacingM,
              AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingM),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 720;
              final title = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EliteLogo(size: 36, showGlow: false),
                  const SizedBox(width: AppTheme.spacingM),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GradientText(
                        text: 'System Control Center',
                        style: AppTheme.headingMedium,
                        gradient: AppTheme.primaryGradient,
                      ),
                      Text('Super Admin workspace', style: AppTheme.bodySmall),
                    ],
                  ),
                ],
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusChip('SUPER ADMIN', AppTheme.accent),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(lastSynced, style: AppTheme.bodySmall),
                  const SizedBox(width: AppTheme.spacingXS),
                  IconButton(
                    onPressed: _loadFacilitators,
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppTheme.primaryBlue),
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: AppTheme.textMuted),
                    tooltip: 'Logout',
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: AppTheme.spacingM),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: actions,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  title,
                  const Spacer(),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── KPI ROW ─────────────────────────────────────────────────────────────

  Widget _buildKPIRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppTheme.spacingS;
          final columns = constraints.maxWidth >= 980
              ? 6
              : constraints.maxWidth >= 640
                  ? 3
                  : 2;
          final itemWidth =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: itemWidth,
                child: _buildKPICard('Users', _totalFacilitators,
                    Icons.people_rounded, AppTheme.primaryBlue),
              ),
              SizedBox(
                width: itemWidth,
                child: _buildKPICard('Approved', _approvedCount,
                    Icons.verified_rounded, AppTheme.success),
              ),
              SizedBox(
                width: itemWidth,
                child: _buildKPICard(
                  'Pending',
                  _pendingFacilitators.length,
                  Icons.hourglass_top_rounded,
                  _pendingFacilitators.isEmpty
                      ? AppTheme.textMuted
                      : AppTheme.warning,
                  highlighted: _pendingFacilitators.isNotEmpty,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _buildKPICard('Rejected', _rejectedCount,
                    Icons.block_rounded, AppTheme.error),
              ),
              SizedBox(
                width: itemWidth,
                child: _buildKPICard('Admins', _adminCount,
                    Icons.admin_panel_settings_rounded, AppTheme.accent),
              ),
              SizedBox(
                width: itemWidth,
                child: _buildKPICard('Clients', _approvedCount,
                    Icons.domain_rounded, AppTheme.primaryPurple),
              ),
              SizedBox(
                width: itemWidth,
                child: _buildKPICard('Total Hunts', _totalActivities,
                    Icons.explore_rounded, AppTheme.accent),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKPICard(
    String label,
    int value,
    IconData icon,
    Color color, {
    bool highlighted = false,
  }) {
    final hasGlow = highlighted && value > 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingM, horizontal: AppTheme.spacingS),
      decoration: BoxDecoration(
        color:
            hasGlow ? color.withValues(alpha: 0.08) : AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: hasGlow
              ? color.withValues(alpha: 0.45)
              : AppTheme.backgroundElevated.withValues(alpha: 0.5),
          width: hasGlow ? 1.5 : 1,
        ),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 16,
                    spreadRadius: 1),
                ...AppTheme.cardShadow,
              ]
            : AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            '$value',
            style: AppTheme.headingSmall.copyWith(
              color: color,
              fontSize: hasGlow ? 22 : 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: AppTheme.labelSmall,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildOperationalSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final children = [
            _buildInsightPanel(
              icon: Icons.fact_check_rounded,
              title: 'Account Health',
              color: AppTheme.success,
              items: [
                _buildInsightItem('Approved users', _approvedCount.toString()),
                _buildInsightItem(
                    'Pending review', _pendingFacilitators.length.toString()),
                _buildInsightItem('Rejected users', _rejectedCount.toString()),
              ],
            ),
            _buildInsightPanel(
              icon: Icons.domain_rounded,
              title: 'Client Workspaces',
              color: AppTheme.primaryPurple,
              items: [
                _buildInsightItem(
                    'With activities', _clientsWithActivities.toString()),
                _buildInsightItem(
                    'No activities yet', _clientsWithoutActivities.toString()),
                _buildInsightItem('Admin accounts', _adminCount.toString()),
              ],
            ),
            _buildInsightPanel(
              icon: Icons.query_stats_rounded,
              title: 'Platform Hunt Stats',
              color: AppTheme.accent,
              items: [
                _buildInsightItem('Total hunts', _totalActivities.toString()),
                _buildInsightItem('Setup', _setupActivities.toString()),
                _buildInsightItem('Live', _activeActivities.toString()),
                _buildInsightItem('Completed', _completedActivities.toString()),
              ],
            ),
          ];

          if (isCompact) {
            return Column(
              children: [
                for (final child in children) ...[
                  child,
                  if (child != children.last)
                    const SizedBox(height: AppTheme.spacingS),
                ],
              ],
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980 ? 3 : 2;
              const gap = AppTheme.spacingS;
              final itemWidth =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final child in children)
                    SizedBox(width: itemWidth, child: child),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInsightPanel({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> items,
  }) {
    return EliteCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(title, style: AppTheme.labelLarge),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInsightItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTheme.bodySmall, overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: AppTheme.labelLarge),
        ],
      ),
    );
  }

  // ─── PENDING SECTION ─────────────────────────────────────────────────────

  Widget _buildPendingSection() {
    final hasPending = _pendingFacilitators.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: hasPending
                ? Icons.warning_amber_rounded
                : Icons.pending_actions_rounded,
            title: 'Pending Approvals',
            count: _pendingFacilitators.length,
            color: hasPending ? AppTheme.warning : AppTheme.textMuted,
          ),
          const SizedBox(height: AppTheme.spacingM),
          if (!hasPending)
            _buildEmptySection(
              icon: Icons.check_circle_outline_rounded,
              title: 'Queue clear',
              message: 'All registration requests have been processed.',
              color: AppTheme.success,
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border:
                    Border.all(color: AppTheme.warning.withValues(alpha: 0.18)),
              ),
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                children: _pendingFacilitators
                    .map((f) => _buildPendingCard(f))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> facilitator) {
    final createdAt = facilitator['created_at'] != null
        ? DateFormat('MMM dd, yyyy · HH:mm')
            .format(DateTime.parse(facilitator['created_at']).toLocal())
        : 'Unknown';

    return EliteCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildInitialAvatar(facilitator['name'], AppTheme.warning),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(facilitator['name'] ?? 'Unknown',
                        style: AppTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(facilitator['email'] ?? '', style: AppTheme.bodySmall),
                  ],
                ),
              ),
              _buildStatusChip('PENDING', AppTheme.warning),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text('Registered $createdAt', style: AppTheme.labelSmall),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectFacilitator(facilitator),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusM),
                      textStyle: AppTheme.buttonMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _approveFacilitator(facilitator),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: AppTheme.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusM),
                      textStyle: AppTheme.buttonMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FACILITATORS SECTION ─────────────────────────────────────────────────

  Widget _buildFacilitatorsSection() {
    final filtered = _searchQuery.isEmpty
        ? _allFacilitators
        : _allFacilitators.where((f) {
            final q = _searchQuery.toLowerCase();
            return (f['name'] as String? ?? '').toLowerCase().contains(q) ||
                (f['email'] as String? ?? '').toLowerCase().contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.people_rounded,
            title: 'All Facilitators',
            count: filtered.length,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: AppTheme.spacingM),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: AppTheme.bodyLarge,
            decoration: AppTheme.inputDecoration(
              label: 'Search by name or email',
              prefixIcon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          if (filtered.isEmpty)
            _buildEmptySection(
              icon: Icons.person_off_rounded,
              title: 'No matching facilitators',
              message: 'Try a different name or email search.',
              color: AppTheme.textMuted,
            )
          else
            ...filtered.map((f) => _buildFacilitatorCard(f)),
        ],
      ),
    );
  }

  Widget _buildFacilitatorCard(Map<String, dynamic> facilitator) {
    final status = facilitator['status'] ?? 'pending';
    final isAdmin = facilitator['is_admin'] == true;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCurrentUser = facilitator['user_id'] == currentUserId;
    final statusColor = _facilitatorStatusColor(status);

    return EliteCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          _buildInitialAvatar(facilitator['name'], statusColor),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        facilitator['name'] ?? 'Unknown',
                        style: AppTheme.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: AppTheme.spacingXS),
                      _buildStatusChip('ADMIN', AppTheme.accent),
                    ],
                    if (isCurrentUser) ...[
                      const SizedBox(width: AppTheme.spacingXS),
                      _buildStatusChip('YOU', AppTheme.primaryPurple),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(facilitator['email'] ?? '',
                    style: AppTheme.bodySmall, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppTheme.spacingXS),
                _buildStatusChip(status.toUpperCase(), statusColor),
              ],
            ),
          ),
          if (!isCurrentUser)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppTheme.textMuted),
              color: AppTheme.backgroundCard,
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
                  _popupItem('approve', Icons.check_rounded, 'Approve',
                      AppTheme.success),
                  _popupItem(
                      'reject', Icons.close_rounded, 'Reject', AppTheme.error),
                ],
                if (status == 'approved')
                  _popupItem(
                    'toggle_admin',
                    isAdmin
                        ? Icons.remove_moderator_rounded
                        : Icons.admin_panel_settings_rounded,
                    isAdmin ? 'Remove Admin' : 'Make Admin',
                    isAdmin ? AppTheme.warning : AppTheme.accent,
                  ),
                _popupItem(
                    'delete', Icons.delete_rounded, 'Delete', AppTheme.error),
              ],
            ),
        ],
      ),
    );
  }

  // ─── ACTIVITIES SECTION ───────────────────────────────────────────────────

  Widget _buildActivitiesSection() {
    final approvedClients = _allFacilitators
        .where((f) => f['status'] == 'approved')
        .toList(growable: false);
    final clientByUserId = {
      for (final f in approvedClients) f['user_id']?.toString(): f,
    };

    final filtered = _allActivities.where((a) {
      final ownerId = a['created_by']?.toString();
      if (_selectedActivityOwnerId != 'all' &&
          ownerId != _selectedActivityOwnerId) {
        return false;
      }

      if (_activitySearchQuery.isEmpty) return true;

      final q = _activitySearchQuery.toLowerCase();
      final facilitatorName = _activityOwnerName(a, clientByUserId);
      return (a['name'] as String? ?? '').toLowerCase().contains(q) ||
          (a['join_code'] as String? ?? '').toLowerCase().contains(q) ||
          facilitatorName.toLowerCase().contains(q) ||
          (a['status'] as String? ?? '').toLowerCase().contains(q);
    }).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final activity in filtered) {
      final ownerId = activity['created_by']?.toString() ?? 'unknown';
      grouped.putIfAbsent(ownerId, () => []).add(activity);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.domain_rounded,
            title: 'Client Activity Workspaces',
            count: grouped.length,
            color: AppTheme.accent,
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildClientSelector(approvedClients),
          const SizedBox(height: AppTheme.spacingS),
          TextField(
            onChanged: (v) => setState(() => _activitySearchQuery = v),
            style: AppTheme.bodyLarge,
            decoration: AppTheme.inputDecoration(
              label: 'Search activity, code, owner, or status',
              prefixIcon: Icons.manage_search_rounded,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          if (filtered.isEmpty)
            _buildEmptySection(
              icon: Icons.explore_off_rounded,
              title: _allActivities.isEmpty
                  ? 'No activities yet'
                  : 'No matching activities',
              message: _allActivities.isEmpty
                  ? 'Activities created by facilitators will appear here.'
                  : 'Try another client, activity name, code, owner, or status.',
              color: AppTheme.textMuted,
            )
          else
            ...grouped.entries.map(
              (entry) => _buildClientActivityGroup(
                ownerId: entry.key,
                client: clientByUserId[entry.key],
                activities: entry.value,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClientSelector(List<Map<String, dynamic>> clients) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildClientFilterChip(
            label: 'All clients',
            value: 'all',
            count: _allActivities.length,
          ),
          const SizedBox(width: AppTheme.spacingS),
          ...clients.map((client) {
            final userId = client['user_id']?.toString() ?? '';
            final count = _allActivities
                .where((a) => a['created_by']?.toString() == userId)
                .length;
            return Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingS),
              child: _buildClientFilterChip(
                label: client['name'] ?? 'Unnamed client',
                value: userId,
                count: count,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildClientFilterChip({
    required String label,
    required String value,
    required int count,
  }) {
    final selected = _selectedActivityOwnerId == value;
    final color = selected ? AppTheme.accent : AppTheme.textMuted;

    return InkWell(
      onTap: () => setState(() => _selectedActivityOwnerId = value),
      borderRadius: BorderRadius.circular(AppTheme.radiusRound),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.12)
              : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusRound),
          border: Border.all(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.45)
                : AppTheme.backgroundElevated.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: AppTheme.spacingS),
            _buildStatusChip(count.toString(), color),
          ],
        ),
      ),
    );
  }

  Widget _buildClientActivityGroup({
    required String ownerId,
    required Map<String, dynamic>? client,
    required List<Map<String, dynamic>> activities,
  }) {
    final clientName = client?['name'] as String? ?? 'Unknown client';
    final clientEmail = client?['email'] as String? ?? ownerId;
    final setup = activities.where((a) {
      final status = a['status'] ?? '';
      return status != 'started' &&
          status != 'active' &&
          status != 'in_progress' &&
          status != 'completed';
    }).length;
    final live = activities.where((a) {
      final status = a['status'] ?? '';
      return status == 'started' ||
          status == 'active' ||
          status == 'in_progress';
    }).length;
    final completed =
        activities.where((a) => a['status'] == 'completed').length;

    return EliteCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildInitialAvatar(clientName, AppTheme.accent),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientName,
                        style: AppTheme.labelLarge,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(clientEmail,
                        style: AppTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _buildStatusChip(
                  '${activities.length} activities', AppTheme.accent),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            spacing: AppTheme.spacingS,
            runSpacing: AppTheme.spacingS,
            children: [
              _buildStatusChip('SETUP $setup', AppTheme.warning),
              _buildStatusChip('LIVE $live', AppTheme.success),
              _buildStatusChip('DONE $completed', AppTheme.info),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          ...activities.map(_buildActivityCard),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final status = activity['status'] ?? 'unknown';
    final facilitatorData = activity['facilitators'];
    final facilitatorName = facilitatorData is Map
        ? (facilitatorData['name'] as String? ?? 'Unknown')
        : 'Unknown';
    final duration = activity['total_duration_minutes'];
    final createdAt = activity['created_at'] != null
        ? DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(activity['created_at']).toLocal())
        : '-';
    final statusColor = _activityStatusColor(status);

    return EliteCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(Icons.explore_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['name'] ?? 'Unnamed',
                    style: AppTheme.labelLarge,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppTheme.spacingXS),
                Row(
                  children: [
                    _buildStatusChip(status.toUpperCase(), statusColor),
                    const SizedBox(width: AppTheme.spacingS),
                    const Icon(Icons.vpn_key_rounded,
                        size: 11, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Text(activity['join_code'] ?? '-',
                        style: AppTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Wrap(
                  spacing: AppTheme.spacingS,
                  runSpacing: 4,
                  children: [
                    _buildMetaItem(
                        Icons.person_outline_rounded, facilitatorName),
                    if (duration != null)
                      _buildMetaItem(Icons.timer_outlined, '${duration}m'),
                    _buildMetaItem(Icons.calendar_today_outlined, createdAt),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteActivity(activity['id'].toString()),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.error, size: 20),
            tooltip: 'Delete activity',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _activityOwnerName(
    Map<String, dynamic> activity,
    Map<String?, Map<String, dynamic>> clientByUserId,
  ) {
    final ownerId = activity['created_by']?.toString();
    final client = clientByUserId[ownerId];
    if (client != null) {
      return client['name'] as String? ?? 'Unknown client';
    }

    final facilitatorData = activity['facilitators'];
    if (facilitatorData is Map) {
      return facilitatorData['name'] as String? ?? 'Unknown client';
    }

    return 'Unknown client';
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    int? count,
    Color? color,
  }) {
    final c = color ?? AppTheme.primaryBlue;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingXS + 2),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: c, size: 16),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Text(title, style: AppTheme.headingSmall),
        if (count != null && count > 0) ...[
          const SizedBox(width: AppTheme.spacingS),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS, vertical: 2),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            ),
            child:
                Text('$count', style: AppTheme.labelSmall.copyWith(color: c)),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptySection({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return EliteCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppTheme.spacingS),
          Text(title, style: AppTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            message,
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String? name, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Center(
        child: Text(
          (name ?? 'U')[0].toUpperCase(),
          style: AppTheme.headingSmall.copyWith(color: color),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: Text(label, style: AppTheme.labelSmall.copyWith(color: color)),
    );
  }

  Widget _buildMetaItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppTheme.textMuted),
        const SizedBox(width: 3),
        Text(label, style: AppTheme.bodySmall),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppTheme.spacingS),
          Text(label,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  Color _facilitatorStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Color _activityStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.success;
      case 'completed':
        return AppTheme.info;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }
}
