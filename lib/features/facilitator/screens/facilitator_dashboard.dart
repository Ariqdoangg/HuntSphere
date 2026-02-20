import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'facilitator_lobby_screen.dart';
import 'activity_setup_screen.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'checkpoint_setup_screen.dart';
import 'facilitator_leaderboard_screen.dart';
import 'admin_management_screen.dart';
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
  String? _facilitatorId;
  bool _isAdmin = false;
  int _pendingApprovals = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
        _isAdmin = facilitator['is_admin'] == true;
      });

      // If admin, load pending approvals count
      if (_isAdmin) {
        final pendingCount = await Supabase.instance.client
            .from('facilitators')
            .select('id')
            .eq('status', 'pending');
        setState(() {
          _pendingApprovals = (pendingCount as List).length;
        });
      }

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
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE53935), size: 28),
            SizedBox(width: 12),
            Text('Delete Activity?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'This will permanently delete this activity and all associated data.',
          style: TextStyle(color: Color(0xFF8892A6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8892A6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1B263B),
              Color(0xFF0D1B2A),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4A90E2),
                          ),
                        )
                      : _activities.isEmpty
                          ? _buildEmptyState()
                          : _buildActivityList(),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // HuntSphere branding (logo + name)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EliteLogo(size: 32, showGlow: false),
              const SizedBox(width: 8),
              GradientText(
                text: 'HuntSphere',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Welcome message (right-aligned)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8892A6),
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                ).createShader(bounds),
                child: Text(
                  _facilitatorName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Admin Management Button (only for admins)
          if (_isAdmin)
            Badge(
              isLabelVisible: _pendingApprovals > 0,
              label: Text('$_pendingApprovals'),
              child: IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminManagementScreen(),
                    ),
                  );
                  // Refresh pending count when returning
                  _loadFacilitatorData();
                },
                icon: const Icon(Icons.admin_panel_settings),
                color: const Color(0xFF00D9FF),
                tooltip: 'Admin Management',
              ),
            ),
          IconButton(
            onPressed: _loadActivities,
            icon: const Icon(Icons.refresh),
            color: const Color(0xFF4A90E2),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            color: const Color(0xFF8892A6),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1500),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1B263B).withOpacity(0.8),
                                const Color(0xFF2A3F5F).withOpacity(0.6),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4A90E2).withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF4A90E2).withOpacity(0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            size: 72,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                    ).createShader(bounds),
                    child: const Text(
                      'No Activities Yet',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create your first activity to get started',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF8892A6),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildCreateButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateButton() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 1.0, end: 1.05),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF7B68EE)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D9FF).withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF7B68EE).withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToCreateActivity(),
                borderRadius: BorderRadius.circular(18),
                splashColor: Colors.white.withOpacity(0.2),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_rounded,
                          color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Create Activity',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          Future.delayed(Duration.zero, () => setState(() {}));
        }
      },
    );
  }

  Widget _buildActivityList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(_activities[index]);
      },
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final status = activity['status'] ?? 'setup';
    final isActive = status == 'started' || status == 'active';
    final isCompleted = status == 'completed';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (value * 0.05),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isActive
                      ? [
                          const Color(0xFF1B263B).withOpacity(0.95),
                          const Color(0xFF2A3F5F).withOpacity(0.90),
                        ]
                      : [
                          const Color(0xFF1B263B).withOpacity(0.90),
                          const Color(0xFF0D1B2A).withOpacity(0.85),
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF4CAF50).withOpacity(0.5)
                      : const Color(0xFF4A90E2).withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -5,
                  ),
                  if (isActive)
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: -5,
                    ),
                  if (!isActive && !isCompleted)
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withOpacity(0.2),
                      blurRadius: 25,
                      spreadRadius: -8,
                    ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isActive
                                        ? [
                                            const Color(0xFF4CAF50),
                                            const Color(0xFF8BC34A)
                                          ]
                                        : [
                                            const Color(0xFF4A90E2),
                                            const Color(0xFF7B68EE)
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isActive
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFF4A90E2))
                                          .withOpacity(0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.rocket_launch_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: isActive
                                      ? [
                                          const Color(0xFF4CAF50),
                                          const Color(0xFF8BC34A)
                                        ]
                                      : [Colors.white, Colors.white70],
                                ).createShader(bounds),
                                child: Text(
                                  activity['name'] ?? 'Untitled Activity',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildStatusBadge(status),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE53935).withOpacity(0.3),
                            ),
                          ),
                          child: IconButton(
                            onPressed: () => _deleteActivity(activity['id']),
                            icon: const Icon(Icons.delete_rounded),
                            color: const Color(0xFFE53935),
                            tooltip: 'Delete Activity',
                          ),
                        ),
              ],
            ),
                    const SizedBox(height: 20),
                    // Stats display with enhanced design
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildTag(
                            icon: Icons.vpn_key_rounded,
                            label: activity['join_code'] ?? 'N/A',
                            color: const Color(0xFF00D9FF),
                          ),
                          _buildTag(
                            icon: Icons.timer_outlined,
                            label:
                                '${activity['total_duration_minutes'] ?? 90} min',
                            color: const Color(0xFFFF9800),
                          ),
                          _buildTag(
                            icon: Icons.event_rounded,
                            label: _formatDate(activity['created_at']),
                            color: const Color(0xFF7B68EE),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildActionButton(
                            label: isActive
                                ? '🎮 Monitor Game'
                                : isCompleted
                                    ? '📊 View Results'
                                    : '👥 View Lobby',
                            icon: isActive
                                ? Icons.monitor_heart_rounded
                                : isCompleted
                                    ? Icons.leaderboard_rounded
                                    : Icons.groups_rounded,
                            isPrimary: true,
                            onTap: () => isActive || isCompleted
                                ? _navigateToMonitor(activity)
                                : _navigateToLobby(activity),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (!isActive && !isCompleted)
                          Expanded(
                            child: _buildActionButton(
                              label: '⚙️ Setup',
                              icon: Icons.settings_rounded,
                              isPrimary: false,
                              onTap: () => _navigateToSetup(activity),
                            ),
                          ),
                      ],
                    ),
                    // Subtle branding footer
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: 0.4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'powered by',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GradientText(
                            text: 'HuntSphere',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color startColor;
    Color endColor;
    String label;
    IconData icon;

    switch (status) {
      case 'started':
      case 'active':
        startColor = const Color(0xFF4CAF50);
        endColor = const Color(0xFF8BC34A);
        label = '🔴 LIVE';
        icon = Icons.play_circle_filled;
        break;
      case 'completed':
        startColor = const Color(0xFF9E9E9E);
        endColor = const Color(0xFFBDBDBD);
        label = '✓ COMPLETED';
        icon = Icons.check_circle;
        break;
      default:
        startColor = const Color(0xFFFF9800);
        endColor = const Color(0xFFFFB74D);
        label = '⚙️ SETUP';
        icon = Icons.settings;
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 1.0, end: 1.08),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [startColor, endColor],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: startColor.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && status == 'active') {
          Future.delayed(Duration.zero, () => setState(() {}));
        }
      },
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.25),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    if (isPrimary) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF7B68EE).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withOpacity(0.2),
            highlightColor: Colors.white.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4A90E2).withOpacity(0.15),
              const Color(0xFF7B68EE).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF4A90E2).withOpacity(0.6),
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: const Color(0xFF4A90E2).withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF4A90E2), size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildFAB() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 1.0, end: 1.05),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF7B68EE)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D9FF).withOpacity(0.6),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF7B68EE).withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToCreateActivity(),
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white.withOpacity(0.2),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_rounded,
                          color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'New Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          Future.delayed(Duration.zero, () => setState(() {}));
        }
      },
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Today';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;

      if (difference == 0) return 'Today';
      if (difference == 1) return 'Yesterday';
      if (difference < 7) return '$difference days ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Today';
    }
  }

  void _navigateToCreateActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActivitySetupScreen(),
      ),
    ).then((_) => _loadActivities());
  }

  void _navigateToLobby(Map<String, dynamic> activity) {
    final status = activity['status'];

    // If activity is already started, go to monitor screen instead
    if (status == 'started' || status == 'active' || status == 'in_progress') {
      _navigateToMonitor(activity);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilitatorLobbyScreen(
          activity: ActivityModel.fromJson(activity),
        ),
      ),
    );
  }

  void _navigateToSetup(Map<String, dynamic> activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckpointSetupScreen(
          activity: ActivityModel.fromJson(activity),
        ),
      ),
    ).then((_) => _loadActivities());
  }

  void _navigateToMonitor(Map<String, dynamic> activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilitatorLeaderboardScreen(
          activityId: activity['id'],
          activityName: activity['name'] ?? 'Activity',
        ),
      ),
    );
  }
}
