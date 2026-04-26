import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'facilitator_lobby_screen.dart';
import 'activity_setup_screen.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'checkpoint_setup_screen.dart';
import 'facilitator_leaderboard_screen.dart';
import 'package:huntsphere/core/theme/app_theme.dart';

class FacilitatorDashboard extends StatefulWidget {
  const FacilitatorDashboard({super.key});

  @override
  State<FacilitatorDashboard> createState() => _FacilitatorDashboardState();
}

class _FacilitatorDashboardState extends State<FacilitatorDashboard>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String _facilitatorName = 'Facilitator';
  String _activityFilter = 'all';
  String _activitySearchQuery = '';
  // ignore: unused_field
  String? _facilitatorId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadFacilitatorData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ─── DATA ────────────────────────────────────────────────────────────────

  Future<void> _loadFacilitatorData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final facilitator = await Supabase.instance.client
          .from('facilitators')
          .select()
          .eq('user_id', user.id)
          .single();

      setState(() {
        _facilitatorName = facilitator['name'] ?? 'Facilitator';
        _facilitatorId = facilitator['id'];
      });

      await _loadActivities();
    } catch (e) {
      debugPrint('Error loading facilitator: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActivities() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final activities = await Supabase.instance.client
          .from('activities')
          .select()
          .eq('created_by', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _activities = List<Map<String, dynamic>>.from(activities);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteActivity(String activityId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusXL),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.error, size: 26),
            const SizedBox(width: AppTheme.spacingM),
            Text('Delete Activity?', style: AppTheme.headingSmall),
          ],
        ),
        content: Text(
          'This will permanently delete this activity and all associated data.',
          style: AppTheme.bodyMedium,
        ),
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
              backgroundColor: AppTheme.error,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusM),
            ),
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
            .eq('id', activityId);
        _loadActivities();
        _showSuccess('Activity deleted');
      } catch (e) {
        _showError('Error deleting activity: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusM),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusM),
    ));
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.backgroundElevated,
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

  List<Map<String, dynamic>> get _visibleActivities {
    return _activities.where((activity) {
      final status = (activity['status'] as String?) ?? '';
      final matchesFilter = switch (_activityFilter) {
        'setup' => _isSetupStatus(status),
        'live' => _isLiveStatus(status),
        'completed' => _isCompletedStatus(status),
        _ => true,
      };

      if (!matchesFilter) return false;
      if (_activitySearchQuery.trim().isEmpty) return true;

      final query = _activitySearchQuery.toLowerCase();
      return (activity['name'] as String? ?? '')
              .toLowerCase()
              .contains(query) ||
          (activity['join_code'] as String? ?? '')
              .toLowerCase()
              .contains(query) ||
          status.toLowerCase().contains(query);
    }).toList();
  }

  Map<String, dynamic>? get _nextActionActivity {
    final live = _activities.where((a) => _isLiveStatus(a['status'] ?? ''));
    if (live.isNotEmpty) return live.first;

    final setup = _activities.where((a) => _isSetupStatus(a['status'] ?? ''));
    if (setup.isNotEmpty) return setup.first;

    final completed =
        _activities.where((a) => _isCompletedStatus(a['status'] ?? ''));
    if (completed.isNotEmpty) return completed.first;

    return null;
  }

  bool _isSetupStatus(String status) =>
      status != 'started' &&
      status != 'active' &&
      status != 'in_progress' &&
      status != 'completed';

  bool _isLiveStatus(String status) =>
      status == 'started' || status == 'active' || status == 'in_progress';

  bool _isCompletedStatus(String status) => status == 'completed';

  void _copyJoinCode(Map<String, dynamic> activity) {
    final code = activity['join_code']?.toString();
    if (code == null || code.isEmpty) {
      _showInfo('No join code available.');
      return;
    }
    Clipboard.setData(ClipboardData(text: code));
    _showSuccess('Join code copied');
  }

  // ─── QUICK ACTION HANDLER ─────────────────────────────────────────────────

  void _handleQuickAction(String action) {
    switch (action) {
      case 'checkpoints':
        final setup = _activities.where((a) {
          final s = a['status'] ?? '';
          return s != 'started' &&
              s != 'active' &&
              s != 'in_progress' &&
              s != 'completed';
        });
        if (setup.isNotEmpty) {
          _navigateToSetup(setup.first);
        } else {
          _showInfo('Create an activity first to add checkpoints.');
        }
        break;
      case 'lobby':
        final lobby = _activities.where((a) {
          final s = a['status'] ?? '';
          return s != 'started' && s != 'active' && s != 'in_progress';
        });
        if (lobby.isNotEmpty) {
          _navigateToLobby(lobby.first);
        } else {
          _showInfo('No activities ready for lobby.');
        }
        break;
      case 'monitor':
        final active = _activities.where((a) {
          final s = a['status'] ?? '';
          return s == 'started' ||
              s == 'active' ||
              s == 'in_progress' ||
              s == 'completed';
        });
        if (active.isNotEmpty) {
          _navigateToMonitor(active.first);
        } else {
          _showInfo('No active or completed activities yet.');
        }
        break;
      case 'reports':
        _showInfo('Reports coming soon.');
        break;
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      floatingActionButton: _isLoading ? null : _buildFAB(),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryBlue),
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildHeroSection()),
                          SliverToBoxAdapter(child: _buildNextActionPanel()),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: AppTheme.spacingM)),
                          SliverToBoxAdapter(child: _buildStatsRow()),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: AppTheme.spacingM)),
                          ..._buildQuickActionSlivers(),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: AppTheme.spacingL)),
                          SliverToBoxAdapter(child: _buildActivityControls()),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: AppTheme.spacingM)),
                          SliverToBoxAdapter(child: _buildSectionHeader()),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: AppTheme.spacingS)),
                          if (_activities.isEmpty) ...[
                            SliverToBoxAdapter(child: _buildEmptyActivities()),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: AppTheme.spacingXXL)),
                          ] else if (_visibleActivities.isEmpty) ...[
                            SliverToBoxAdapter(
                                child: _buildNoMatchingActivities()),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: AppTheme.spacingXXL)),
                          ] else ...[
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                  AppTheme.spacingL,
                                  AppTheme.spacingS,
                                  AppTheme.spacingL,
                                  AppTheme.spacingXXL),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => Center(
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 900),
                                      child: _buildActivityCard(
                                          _visibleActivities[index]),
                                    ),
                                  ),
                                  childCount: _visibleActivities.length,
                                ),
                              ),
                            ),
                            ..._buildRecentResultSlivers(),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingM, AppTheme.spacingM,
          AppTheme.spacingXS, AppTheme.spacingS),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EliteLogo(size: 32, showGlow: false),
              const SizedBox(width: AppTheme.spacingS),
              GradientText(
                text: 'HuntSphere',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                gradient: AppTheme.primaryGradient,
              ),
            ],
          ),
          const Spacer(),
          if (!isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Welcome back,', style: AppTheme.bodySmall),
                GradientText(
                  text: _facilitatorName,
                  style: AppTheme.headingSmall,
                  gradient: AppTheme.primaryGradient,
                ),
              ],
            ),
            const SizedBox(width: AppTheme.spacingM),
          ],
          _buildRoleBadge(),
          const SizedBox(width: AppTheme.spacingXS),
          IconButton(
            onPressed: _loadActivities,
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.primaryBlue,
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            color: AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  // ─── ROLE BADGE ──────────────────────────────────────────────────────────

  Widget _buildRoleBadge() {
    const color = AppTheme.primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS + 2, vertical: AppTheme.spacingXS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Facilitator',
        style: AppTheme.labelSmall.copyWith(color: color),
      ),
    );
  }

  // ─── HERO SECTION ────────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacingM,
              AppTheme.spacingL, AppTheme.spacingM, AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              GradientText(
                text: _facilitatorName,
                style: AppTheme.headingSmall
                    .copyWith(fontSize: 26, fontWeight: FontWeight.w700),
                gradient: AppTheme.primaryGradient,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Ready to run your next hunt?',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: AppTheme.spacingL),
              if (isMobile) ...[
                SizedBox(
                  width: double.infinity,
                  child: EliteButton(
                    label: 'Create Activity',
                    icon: Icons.add_rounded,
                    height: 56,
                    onPressed: _navigateToCreateActivity,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                SizedBox(
                  width: double.infinity,
                  child: EliteButton(
                    label: 'View Reports',
                    icon: Icons.bar_chart_rounded,
                    isOutlined: true,
                    height: 44,
                    onPressed: () => _handleQuickAction('reports'),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    EliteButton(
                      label: 'Create Activity',
                      icon: Icons.add_rounded,
                      width: 180,
                      height: 56,
                      onPressed: _navigateToCreateActivity,
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    EliteButton(
                      label: 'View Reports',
                      icon: Icons.bar_chart_rounded,
                      isOutlined: true,
                      width: 150,
                      height: 44,
                      onPressed: () => _handleQuickAction('reports'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNextActionPanel() {
    final activity = _nextActionActivity;

    if (activity == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
        child: EliteCard(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 620;
              final icon = Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(Icons.add_task_rounded,
                    color: AppTheme.primaryBlue, size: 28),
              );
              final text = Column(
                crossAxisAlignment: isMobile
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text('Start your next hunt', style: AppTheme.headingSmall),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Create an activity, add checkpoints, and prepare the lobby for participants.',
                    style: AppTheme.bodyMedium,
                    textAlign: isMobile ? TextAlign.center : null,
                  ),
                ],
              );
              final button = EliteButton(
                label: 'Create Activity',
                icon: Icons.add_rounded,
                width: isMobile ? double.infinity : 180,
                height: 48,
                onPressed: _navigateToCreateActivity,
              );

              if (isMobile) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: AppTheme.spacingM),
                    text,
                    const SizedBox(height: AppTheme.spacingM),
                    button,
                  ],
                );
              }

              return Row(
                children: [
                  icon,
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(child: text),
                  const SizedBox(width: AppTheme.spacingM),
                  button,
                ],
              );
            },
          ),
        ),
      );
    }

    final status = (activity['status'] as String?) ?? '';
    final isLive = _isLiveStatus(status);
    final isCompleted = _isCompletedStatus(status);
    final color = isLive
        ? AppTheme.success
        : isCompleted
            ? AppTheme.info
            : AppTheme.warning;
    final title = isLive
        ? 'Live hunt needs monitoring'
        : isCompleted
            ? 'Review recent results'
            : 'Continue setup';
    final actionLabel = isLive
        ? 'Monitor Now'
        : isCompleted
            ? 'View Results'
            : 'Continue Setup';
    final actionIcon = isLive
        ? Icons.monitor_heart_rounded
        : isCompleted
            ? Icons.leaderboard_rounded
            : Icons.settings_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: EliteCard(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;
            final details = Column(
              crossAxisAlignment: isMobile
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: color, size: 18),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text('Next Action',
                        style: AppTheme.labelSmall.copyWith(color: color)),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(title, style: AppTheme.headingSmall),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  activity['name'] ?? 'Untitled Activity',
                  style: AppTheme.bodyMedium,
                  textAlign: isMobile ? TextAlign.center : null,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Wrap(
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  alignment:
                      isMobile ? WrapAlignment.center : WrapAlignment.start,
                  children: [
                    _buildTag(
                      icon: Icons.vpn_key_rounded,
                      label: activity['join_code'] ?? 'N/A',
                      color: AppTheme.accent,
                    ),
                    _buildTag(
                      icon: Icons.event_rounded,
                      label: _formatDate(activity['created_at']),
                      color: AppTheme.primaryPurple,
                    ),
                  ],
                ),
              ],
            );

            final actions = Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingS,
              alignment: isMobile ? WrapAlignment.center : WrapAlignment.end,
              children: [
                EliteButton(
                  label: actionLabel,
                  icon: actionIcon,
                  width: isMobile ? constraints.maxWidth : 170,
                  height: 46,
                  onPressed: () => isLive || isCompleted
                      ? _navigateToMonitor(activity)
                      : _navigateToSetup(activity),
                ),
                EliteButton(
                  label: 'Copy Code',
                  icon: Icons.copy_rounded,
                  isOutlined: true,
                  width: isMobile ? constraints.maxWidth : 140,
                  height: 46,
                  onPressed: () => _copyJoinCode(activity),
                ),
              ],
            );

            if (isMobile) {
              return Column(
                children: [
                  details,
                  const SizedBox(height: AppTheme.spacingM),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: AppTheme.spacingM),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── STATS ROW ───────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final liveCount = _activities.where((a) {
      final s = a['status'] ?? '';
      return _isLiveStatus(s);
    }).length;
    final setupCount =
        _activities.where((a) => _isSetupStatus(a['status'] ?? '')).length;

    final completedCount =
        _activities.where((a) => _isCompletedStatus(a['status'] ?? '')).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          if (isMobile) {
            return Column(
              children: [
                _buildStatCard(
                  'Total',
                  _activities.length,
                  Icons.grid_view_rounded,
                  AppTheme.primaryBlue,
                ),
                const SizedBox(height: AppTheme.spacingS),
                _buildStatCard(
                  'Setup',
                  setupCount,
                  Icons.tune_rounded,
                  AppTheme.warning,
                ),
                const SizedBox(height: AppTheme.spacingS),
                _buildStatCard(
                  'Live',
                  liveCount,
                  Icons.play_circle_rounded,
                  AppTheme.success,
                ),
                const SizedBox(height: AppTheme.spacingS),
                _buildStatCard(
                  'Done',
                  completedCount,
                  Icons.check_circle_rounded,
                  AppTheme.info,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _activities.length,
                  Icons.grid_view_rounded,
                  AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: _buildStatCard(
                  'Setup',
                  setupCount,
                  Icons.tune_rounded,
                  AppTheme.warning,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: _buildStatCard(
                  'Live',
                  liveCount,
                  Icons.play_circle_rounded,
                  AppTheme.success,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: _buildStatCard(
                  'Done',
                  completedCount,
                  Icons.check_circle_rounded,
                  AppTheme.info,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return EliteCard(
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingM, horizontal: AppTheme.spacingS),
      child: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: AppTheme.headingSmall.copyWith(color: color)),
                Text(
                  label,
                  style: AppTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── QUICK ACTIONS ────────────────────────────────────────────────────────

  List<Widget> _buildQuickActionSlivers() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          child: Text('Quick Actions', style: AppTheme.headingSmall),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingM)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.crossAxisExtent >= 540 ? 3 : 2;
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: AppTheme.spacingS,
                crossAxisSpacing: AppTheme.spacingS,
                childAspectRatio: 1.6,
              ),
              delegate: SliverChildListDelegate(
                [
                  _buildQuickActionCard(
                    Icons.add_circle_rounded,
                    'New Activity',
                    AppTheme.primaryBlue,
                    _navigateToCreateActivity,
                  ),
                  _buildQuickActionCard(
                    Icons.flag_rounded,
                    'Checkpoints',
                    AppTheme.warning,
                    () => _handleQuickAction('checkpoints'),
                  ),
                  _buildQuickActionCard(
                    Icons.groups_rounded,
                    'Lobby',
                    AppTheme.success,
                    () => _handleQuickAction('lobby'),
                  ),
                  _buildQuickActionCard(
                    Icons.monitor_heart_rounded,
                    'Monitor',
                    AppTheme.info,
                    () => _handleQuickAction('monitor'),
                  ),
                  _buildQuickActionCard(
                    Icons.bar_chart_rounded,
                    'Reports',
                    AppTheme.primaryPurple,
                    () => _handleQuickAction('reports'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildQuickActionCard(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return EliteCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingM, horizontal: AppTheme.spacingS),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            label,
            style: AppTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── SECTION HEADER ──────────────────────────────────────────────────────

  Widget _buildActivityControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _activities.length),
                const SizedBox(width: AppTheme.spacingS),
                _buildFilterChip(
                  'Setup',
                  'setup',
                  _activities
                      .where((a) => _isSetupStatus(a['status'] ?? ''))
                      .length,
                ),
                const SizedBox(width: AppTheme.spacingS),
                _buildFilterChip(
                  'Live',
                  'live',
                  _activities
                      .where((a) => _isLiveStatus(a['status'] ?? ''))
                      .length,
                ),
                const SizedBox(width: AppTheme.spacingS),
                _buildFilterChip(
                  'Completed',
                  'completed',
                  _activities
                      .where((a) => _isCompletedStatus(a['status'] ?? ''))
                      .length,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          TextField(
            onChanged: (value) => setState(() => _activitySearchQuery = value),
            style: AppTheme.bodyLarge,
            decoration: AppTheme.inputDecoration(
              label: 'Search activity or join code',
              prefixIcon: Icons.search_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final selected = _activityFilter == value;
    final color = selected ? AppTheme.primaryBlue : AppTheme.textMuted;

    return InkWell(
      onTap: () => setState(() => _activityFilter = value),
      borderRadius: BorderRadius.circular(AppTheme.radiusRound),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryBlue.withValues(alpha: 0.12)
              : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusRound),
          border: Border.all(
            color: selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.45)
                : AppTheme.backgroundElevated.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTheme.labelMedium.copyWith(color: color)),
            const SizedBox(width: AppTheme.spacingS),
            Text('$count', style: AppTheme.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    final label = switch (_activityFilter) {
      'setup' => 'Setup Activities',
      'live' => 'Live Activities',
      'completed' => 'Completed Activities',
      _ => 'My Activities',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Row(
        children: [
          Text(label, style: AppTheme.headingSmall),
          const Spacer(),
          Text('${_visibleActivities.length} shown', style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────────────────────────

  Widget _buildEmptyActivities() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: EliteCard(
            padding: const EdgeInsets.all(AppTheme.spacingXXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                    border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(Icons.explore_rounded,
                      color: AppTheme.primaryBlue, size: 48),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'Create your first hunt',
                  style: AppTheme.headingSmall.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'Set up checkpoints, assign tasks, and run a live leaderboard experience.',
                  style:
                      AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXL),
                SizedBox(
                  width: double.infinity,
                  child: EliteButton(
                    label: 'Create Activity',
                    icon: Icons.add_rounded,
                    height: 56,
                    onPressed: _navigateToCreateActivity,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatchingActivities() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: EliteCard(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.manage_search_rounded,
                    color: AppTheme.textMuted, size: 42),
                const SizedBox(height: AppTheme.spacingM),
                Text('No matching activities', style: AppTheme.headingSmall),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'Try another status filter, activity name, or join code.',
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRecentResultSlivers() {
    final completed = _activities
        .where((activity) => _isCompletedStatus(activity['status'] ?? ''))
        .take(3)
        .toList();

    if (completed.isEmpty) return [];

    return [
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingL)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          child: Text('Recent Results', style: AppTheme.headingSmall),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingS)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingM,
          0,
          AppTheme.spacingM,
          AppTheme.spacingXXL,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildResultCard(completed[index]),
            childCount: completed.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildResultCard(Map<String, dynamic> activity) {
    return EliteCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(Icons.leaderboard_rounded,
                color: AppTheme.info, size: 20),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['name'] ?? 'Untitled Activity',
                  style: AppTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(_formatDate(activity['created_at']),
                    style: AppTheme.bodySmall),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _navigateToMonitor(activity),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Results'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final status = activity['status'] ?? 'setup';
    final isActive = status == 'started' || status == 'active';
    final isCompleted = status == 'completed';
    final accentColor = isActive
        ? AppTheme.success
        : isCompleted
            ? AppTheme.textDisabled
            : AppTheme.primaryBlue;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final pad = isMobile
                ? const EdgeInsets.all(AppTheme.spacingM - 4)
                : const EdgeInsets.all(AppTheme.spacingM);
            final iconPad = isMobile
                ? const EdgeInsets.all(AppTheme.spacingS)
                : const EdgeInsets.all(AppTheme.spacingM);
            final gap = isMobile ? 10.0 : AppTheme.spacingM;
            final btnH = isMobile ? 36.0 : 44.0;

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                  if (isActive)
                    BoxShadow(
                      color: AppTheme.success.withValues(alpha: 0.14),
                      blurRadius: 20,
                      spreadRadius: -2,
                    ),
                ],
              ),
              padding: const EdgeInsets.all(1.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusL - 1),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isActive
                              ? [
                                  AppTheme.backgroundCard,
                                  AppTheme.backgroundElevated
                                ]
                              : [
                                  AppTheme.backgroundCard,
                                  AppTheme.backgroundMedium
                                ],
                        ),
                      ),
                      child: Padding(
                        padding: pad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: icon + name + delete
                            Row(
                              children: [
                                Container(
                                  padding: iconPad,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isActive
                                          ? [
                                              AppTheme.success,
                                              AppTheme.successDark
                                            ]
                                          : [
                                              AppTheme.primaryBlue,
                                              AppTheme.primaryPurple
                                            ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusM),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isActive
                                                ? AppTheme.success
                                                : AppTheme.primaryBlue)
                                            .withValues(alpha: 0.28),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.rocket_launch_rounded,
                                    color: AppTheme.textPrimary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: Text(
                                    activity['name'] ?? 'Untitled Activity',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: AppTheme.headingSmall,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                IconButton(
                                  onPressed: () => _copyJoinCode(activity),
                                  icon: const Icon(Icons.copy_rounded),
                                  color: AppTheme.accent,
                                  iconSize: 18,
                                  padding:
                                      const EdgeInsets.all(AppTheme.spacingS),
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Copy Join Code',
                                ),
                                const SizedBox(width: AppTheme.spacingXS),
                                Container(
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.error.withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusS),
                                    border: Border.all(
                                        color: AppTheme.error
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: IconButton(
                                    onPressed: () =>
                                        _deleteActivity(activity['id']),
                                    icon: const Icon(Icons.delete_rounded),
                                    color: AppTheme.error,
                                    iconSize: 18,
                                    padding:
                                        const EdgeInsets.all(AppTheme.spacingS),
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Delete Activity',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            _buildStatusBadge(status),
                            SizedBox(height: gap),
                            Wrap(
                              spacing: AppTheme.spacingS,
                              runSpacing: AppTheme.spacingS,
                              children: [
                                _buildTag(
                                  icon: Icons.vpn_key_rounded,
                                  label: activity['join_code'] ?? 'N/A',
                                  color: AppTheme.accent,
                                ),
                                _buildTag(
                                  icon: Icons.timer_outlined,
                                  label:
                                      '${activity['total_duration_minutes'] ?? 90} min',
                                  color: AppTheme.warning,
                                ),
                                _buildTag(
                                  icon: Icons.event_rounded,
                                  label: _formatDate(activity['created_at']),
                                  color: AppTheme.primaryPurple,
                                ),
                              ],
                            ),
                            SizedBox(height: gap),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: EliteButton(
                                    label: isActive
                                        ? 'Monitor Game'
                                        : isCompleted
                                            ? 'View Results'
                                            : 'View Lobby',
                                    icon: isActive
                                        ? Icons.monitor_heart_rounded
                                        : isCompleted
                                            ? Icons.leaderboard_rounded
                                            : Icons.groups_rounded,
                                    height: btnH,
                                    onPressed: () => isActive || isCompleted
                                        ? _navigateToMonitor(activity)
                                        : _navigateToLobby(activity),
                                  ),
                                ),
                                if (!isActive && !isCompleted) ...[
                                  const SizedBox(width: AppTheme.spacingS),
                                  Expanded(
                                    child: EliteButton(
                                      label: 'Setup',
                                      icon: Icons.settings_rounded,
                                      isOutlined: true,
                                      height: btnH,
                                      onPressed: () =>
                                          _navigateToSetup(activity),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: gap),
                            Opacity(
                              opacity: 0.35,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('powered by',
                                      style: AppTheme.labelSmall),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  GradientText(
                                    text: 'HuntSphere',
                                    style: AppTheme.caption,
                                    gradient: AppTheme.primaryGradient,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 4, color: accentColor),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── STATUS BADGE ─────────────────────────────────────────────────────────

  Widget _buildStatusBadge(String status) {
    final Color startColor;
    final Color endColor;
    final String label;

    switch (status) {
      case 'started':
      case 'active':
        startColor = AppTheme.success;
        endColor = AppTheme.successDark;
        label = 'LIVE';
        break;
      case 'completed':
        startColor = AppTheme.textDisabled;
        endColor = AppTheme.textMuted;
        label = 'COMPLETED';
        break;
      default:
        startColor = AppTheme.warning;
        endColor = AppTheme.warningDark;
        label = 'SETUP';
    }

    final isLive = status == 'active' || status == 'started';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1400),
      tween: Tween(begin: 1.0, end: isLive ? 1.06 : 1.0),
      curve: Curves.easeInOut,
      builder: (context, scale, _) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingXS + 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [startColor, endColor]),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
              boxShadow: [
                BoxShadow(
                  color: startColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              label,
              style: AppTheme.caption.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && isLive) {
          Future.delayed(Duration.zero, () {
            if (mounted) setState(() {});
          });
        }
      },
    );
  }

  // ─── TAG CHIP ─────────────────────────────────────────────────────────────

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS + 2, vertical: AppTheme.spacingXS + 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppTheme.spacingXS + 2),
          Text(label,
              style:
                  AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // ─── FAB ─────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.primaryShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToCreateActivity,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM, vertical: AppTheme.spacingM - 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded,
                    color: AppTheme.textPrimary, size: 20),
                const SizedBox(width: AppTheme.spacingS),
                Text('New Activity', style: AppTheme.buttonMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Today';
    try {
      final date = DateTime.parse(dateString);
      final diff = DateTime.now().difference(date).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) return '$diff days ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Today';
    }
  }

  void _navigateToCreateActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivitySetupScreen()),
    ).then((_) => _loadActivities());
  }

  void _navigateToLobby(Map<String, dynamic> activity) {
    final status = activity['status'];
    if (status == 'started' || status == 'active' || status == 'in_progress') {
      _navigateToMonitor(activity);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FacilitatorLobbyScreen(
          activity: ActivityModel.fromJson(activity),
        ),
      ),
    );
  }

  void _navigateToSetup(Map<String, dynamic> activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckpointSetupScreen(
          activity: ActivityModel.fromJson(activity),
        ),
      ),
    ).then((_) => _loadActivities());
  }

  void _navigateToMonitor(Map<String, dynamic> activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FacilitatorLeaderboardScreen(
          activityId: activity['id'],
          activityName: activity['name'] ?? 'Activity',
        ),
      ),
    );
  }
}
