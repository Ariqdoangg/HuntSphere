import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/services/audio_service.dart';
import '../../shared/screens/photo_gallery_screen.dart';

class FacilitatorLeaderboardScreen extends StatefulWidget {
  final String activityId;
  final String activityName;

  const FacilitatorLeaderboardScreen({
    super.key,
    required this.activityId,
    required this.activityName,
  });

  @override
  State<FacilitatorLeaderboardScreen> createState() =>
      _FacilitatorLeaderboardScreenState();
}

class _FacilitatorLeaderboardScreenState
    extends State<FacilitatorLeaderboardScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> pendingSubmissions = [];
  bool isLoading = true;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  int totalCheckpoints = 0;
  Map<String, dynamic>? activityData;
  Duration _remainingTime = Duration.zero;
  bool _isTimeUp = false;

  // Animation controllers for elite UI
  late AnimationController _badgeAnimationController;
  late Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _badgeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _badgeAnimationController.forward();

    _loadData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadData();
    });

    // Start countdown timer (updates every second)
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _badgeAnimationController.dispose();
    super.dispose();
  }

  void _updateCountdown() {
    if (activityData == null) return;

    final gameStartedAt = activityData!['game_started_at'];
    // Always use total_duration_minutes (set by facilitator at creation)
    // duration_minutes column is unreliable (has DEFAULT 60 in DB)
    final durationMinutes = activityData!['total_duration_minutes'] ?? 60;

    if (gameStartedAt == null) return;

    final startTime = DateTime.parse(gameStartedAt);
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    final now = DateTime.now();
    final remaining = endTime.difference(now);

    if (mounted) {
      setState(() {
        if (remaining.isNegative) {
          _remainingTime = Duration.zero;
          if (!_isTimeUp) {
            _isTimeUp = true;
            _autoEndActivity();
          }
        } else {
          _remainingTime = remaining;
        }
      });
    }
  }

  Future<void> _autoEndActivity() async {
    // Auto-end when timer reaches zero
    try {
      await Supabase.instance.client
          .from('activities')
          .update({
            'status': 'completed',
            'game_ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.activityId);

      // Play activity end sound and haptic feedback
      await AudioService().play('activity_end');
      HapticFeedback.heavyImpact();

      _showSuccess('⏰ Time is up! Activity ended automatically.');

      // Navigate to results
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/results',
          arguments: {
            'activityId': widget.activityId,
            'isFacilitator': true,
          },
        );
      }
    } catch (e) {
      debugPrint('Error auto-ending activity: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    try {
      // Load activity data
      final activityResponse = await Supabase.instance.client
          .from('activities')
          .select()
          .eq('id', widget.activityId)
          .single();

      debugPrint('Loading teams for activity: ${widget.activityId}');

      // Load teams - order by points DESC, then by finished_at ASC (faster = better)
      final teamsResponse = await Supabase.instance.client
          .from('teams')
          .select()
          .eq('activity_id', widget.activityId)
          .order('total_points', ascending: false)
          .order('finished_at', ascending: true, nullsFirst: false);

      debugPrint('Teams loaded: ${teamsResponse.length} teams found');
      debugPrint('Teams data: $teamsResponse');

      // Load pending submissions for this activity only
      // First get team IDs for this activity
      final teamIds = (teamsResponse as List).map((t) => t['id']).toList();

      List<Map<String, dynamic>> submissionsResponse = [];
      if (teamIds.isNotEmpty) {
        submissionsResponse = await Supabase.instance.client
            .from('task_submissions')
            .select('''
              *,
              tasks (title, points),
              teams (team_name, emoji),
              participants (name)
            ''')
            .inFilter('team_id', teamIds)
            .eq('status', 'pending')
            .order('submitted_at', ascending: false);
      }

      // Load checkpoint count
      final checkpointsResponse = await Supabase.instance.client
          .from('checkpoints')
          .select('id')
          .eq('activity_id', widget.activityId);

      if (mounted) {
        setState(() {
          activityData = activityResponse;
          teams = List<Map<String, dynamic>>.from(teamsResponse);
          pendingSubmissions =
              List<Map<String, dynamic>>.from(submissionsResponse);
          totalCheckpoints = (checkpointsResponse as List).length;
          isLoading = false;
        });
        debugPrint('State updated - Teams count: ${teams.length}');
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _approveSubmission(Map<String, dynamic> submission) async {
    try {
      final submissionId = submission['id'];
      final points = submission['tasks']?['points'] ?? 0;
      final teamId = submission['team_id'];

      // Validate inputs
      if (submissionId == null || teamId == null) {
        _showError('Invalid submission data');
        return;
      }

      if (points <= 0 || points > 10000) {  // Sanity check
        _showError('Invalid points value: $points');
        return;
      }

      // Check current status FIRST to prevent duplicate points
      final current = await Supabase.instance.client
          .from('task_submissions')
          .select('status')
          .eq('id', submissionId)
          .single();

      if (current['status'] == 'approved') {
        _showError('Submission already approved');
        return;  // Prevents duplicate points
      }

      // Update status
      await Supabase.instance.client
          .from('task_submissions')
          .update({
            'status': 'approved',
            'points_awarded': points,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', submissionId);

      // Award points (now safe from duplicates)
      await Supabase.instance.client.rpc('increment_team_points', params: {
        'team_id_param': teamId,
        'points_to_add': points,
      });

      debugPrint('✅ +$points points added to team total');
      _showSuccess('Submission approved! +$points points');
      _loadData();

    } catch (e) {
      debugPrint('Error approving submission: $e');
      _showError('Failed to approve submission. Please try again.');
    }
  }

  Future<void> _rejectSubmission(Map<String, dynamic> submission) async {
    try {
      await Supabase.instance.client
          .from('task_submissions')
          .update({
            'status': 'rejected',
            'points_awarded': 0,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', submission['id']);

      _showSuccess('Submission rejected');
      _loadData();
    } catch (e) {
      _showError('Error rejecting: $e');
    }
  }

  Future<void> _endActivity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text(
          'End Activity?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will end the activity and show final results to all participants.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('End Activity'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('activities')
            .update({
              'status': 'completed',
              'game_ended_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.activityId);

        _showSuccess('Activity ended!');

        // Navigate to results (as facilitator)
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/results',
            arguments: {
              'activityId': widget.activityId,
              'isFacilitator': true,
            },
          );
        }
      } catch (e) {
        _showError('Error ending activity: $e');
      }
    }
  }

  // ============ BONUS POINTS ============
  Future<void> _showBonusPointsDialog(Map<String, dynamic> team) async {
    final pointsController = TextEditingController();
    final reasonController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: Row(
          children: [
            const Text('🎁 ', style: TextStyle(fontSize: 24)),
            const Text('Bonus Points', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Give bonus points to ${team['team_name']}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Points',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0A1628),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0A1628),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final points = int.tryParse(pointsController.text) ?? 0;
              if (points > 0) {
                Navigator.pop(context, {
                  'points': points,
                  'reason': reasonController.text,
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Give Bonus', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (result != null) {
      await _giveBonusPoints(team, result['points'], result['reason']);
    }
  }

  Future<void> _giveBonusPoints(Map<String, dynamic> team, int points, String reason) async {
    try {
      final currentPoints = team['total_points'] ?? 0;
      await Supabase.instance.client
          .from('teams')
          .update({'total_points': currentPoints + points})
          .eq('id', team['id']);

      _showSuccess('🎁 +$points bonus points to ${team['team_name']}!');
      _loadData();
    } catch (e) {
      _showError('Error giving bonus: $e');
    }
  }

  // ============ ANNOUNCEMENT/BROADCAST ============
  Future<void> _showAnnouncementDialog() async {
    final messageController = TextEditingController();

    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Row(
          children: [
            Text('📢 ', style: TextStyle(fontSize: 24)),
            Text('Send Announcement', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This message will be shown to all participants.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0A1628),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.trim().isNotEmpty) {
                Navigator.pop(context, messageController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF)),
            child: const Text('Send', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (message != null) {
      await _sendAnnouncement(message);
    }
  }

  Future<void> _sendAnnouncement(String message) async {
    try {
      await Supabase.instance.client.from('announcements').insert({
        'activity_id': widget.activityId,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccess('📢 Announcement sent to all participants!');
    } catch (e) {
      // If announcements table doesn't exist, show message anyway
      _showSuccess('📢 Announcement: $message');
    }
  }

  // ============ EXTEND TIME ============
  Future<void> _showExtendTimeDialog() async {
    int selectedMinutes = 15;

    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          title: const Row(
            children: [
              Text('⏰ ', style: TextStyle(fontSize: 24)),
              Text('Extend Time', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add more time to the activity',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 10, 15, 30].map((min) {
                  final isSelected = selectedMinutes == min;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedMinutes = min),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF00D9FF) : const Color(0xFF0A1628),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF00D9FF) : Colors.white24,
                        ),
                      ),
                      child: Text(
                        '+$min',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '$selectedMinutes minutes',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedMinutes),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9FF)),
              child: const Text('Extend', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );

    if (minutes != null) {
      await _extendTime(minutes);
    }
  }

  Future<void> _extendTime(int minutes) async {
    try {
      // Read the actual duration the facilitator set
      final currentDuration = activityData?['total_duration_minutes'] ?? 60;
      final newDuration = currentDuration + minutes;

      // Update total_duration_minutes (the column the timer reads)
      await Supabase.instance.client
          .from('activities')
          .update({'total_duration_minutes': newDuration})
          .eq('id', widget.activityId);

      _showSuccess('⏰ Time extended by $minutes minutes!');
      _loadData();
    } catch (e) {
      _showError('Error extending time: $e');
    }
  }

  // ============ SHOW MORE OPTIONS ============
  void _showMoreOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Facilitator Actions',
              style: AppTheme.headingSmall,
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildOptionTile(
              icon: Icons.campaign_rounded,
              iconColor: AppTheme.accent,
              title: 'Send Announcement',
              subtitle: 'Broadcast message to all participants',
              onTap: () {
                Navigator.pop(context);
                _showAnnouncementDialog();
              },
            ),
            _buildOptionTile(
              icon: Icons.more_time_rounded,
              iconColor: AppTheme.warning,
              title: 'Extend Time',
              subtitle: 'Add more time to the activity',
              onTap: () {
                Navigator.pop(context);
                _showExtendTimeDialog();
              },
            ),
            _buildOptionTile(
              icon: Icons.stop_circle_rounded,
              iconColor: AppTheme.error,
              title: 'End Activity',
              subtitle: 'End the game and show results',
              onTap: () {
                Navigator.pop(context);
                _endActivity();
              },
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        tileColor: AppTheme.backgroundInput,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppTheme.caption.copyWith(color: AppTheme.textMuted)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 16),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.success,
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
    final isTimeLow = _remainingTime.inMinutes < 5 && _remainingTime.inSeconds > 0;

    return DefaultTabController(
      length: 2,
      child: EliteScaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HuntSphere branding
              EliteLogo(size: 28, showGlow: false),
              const SizedBox(width: 10),
              // Activity name and timer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App name with gradient
                    GradientText(
                      text: 'HuntSphere',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.primaryPurple],
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Activity name
                    Text(
                      widget.activityName,
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Timer display
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isTimeLow
                            ? AppTheme.error.withValues(alpha: 0.2)
                            : AppTheme.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: 12,
                            color: isTimeLow ? AppTheme.error : AppTheme.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _remainingTime.inSeconds > 0
                                ? _formatDuration(_remainingTime)
                                : 'Time Up!',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: isTimeLow ? AppTheme.error : AppTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          bottom: TabBar(
            indicatorColor: AppTheme.accent,
            indicatorWeight: 3,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.leaderboard_rounded), text: 'Rankings'),
              Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Review'),
            ],
          ),
          actions: [
            // Photo Gallery Button (only show when activity is completed)
            if (activityData?['status'] == 'completed')
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Icon(Icons.photo_library_rounded, size: 20, color: AppTheme.accent),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PhotoGalleryScreen(
                        activityId: widget.activityId,
                        activityName: widget.activityName,
                      ),
                    ),
                  );
                },
                tooltip: 'Photo Gallery',
              ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCard.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(Icons.refresh, size: 20),
              ),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCard.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(Icons.more_vert, size: 20),
              ),
              onPressed: _showMoreOptions,
              tooltip: 'More Options',
            ),
            const SizedBox(width: AppTheme.spacingS),
          ],
        ),
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
              : TabBarView(
                  children: [
                    _buildRankingsTab(),
                    _buildReviewTab(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRankingsTab() {
    return Column(
      children: [
        // Stats header
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          margin: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.15),
                AppTheme.primaryPurple.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(
              color: AppTheme.backgroundElevated.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Teams', teams.length.toString(), Icons.groups_rounded, AppTheme.accent),
              _buildStat('Pending', pendingSubmissions.length.toString(),
                  Icons.pending_actions_rounded, AppTheme.warning),
              _buildStat('Checkpoints', totalCheckpoints.toString(),
                  Icons.location_on_rounded, AppTheme.success),
            ],
          ),
        ),

        // Teams list
        Expanded(
          child: teams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 64,
                        color: AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Text(
                        'No teams yet',
                        style: AppTheme.headingSmall.copyWith(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return _buildTeamCard(team, index + 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          value,
          style: AppTheme.headingMedium.copyWith(color: color),
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int rank) {
    Color rankColor;
    IconData rankIcon;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD700);
        rankIcon = Icons.emoji_events_rounded;
        break;
      case 2:
        rankColor = const Color(0xFFC0C0C0);
        rankIcon = Icons.emoji_events_rounded;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32);
        rankIcon = Icons.emoji_events_rounded;
        break;
      default:
        rankColor = AppTheme.textMuted;
        rankIcon = Icons.tag_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: EliteCard(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        gradient: rank <= 3
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  rankColor.withValues(alpha: 0.15),
                  AppTheme.backgroundCard,
                ],
              )
            : null,
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: rank <= 3
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          rankColor.withValues(alpha: 0.3),
                          rankColor.withValues(alpha: 0.1),
                        ],
                      )
                    : null,
                color: rank > 3 ? AppTheme.backgroundElevated : null,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: rankColor.withValues(alpha: 0.5),
                  width: rank <= 3 ? 2 : 1,
                ),
                // Add glow shadow for top 3 ranks
                boxShadow: rank <= 3
                    ? [
                        ...AppTheme.glowShadow(rankColor),
                        ...AppTheme.cardShadow,
                      ]
                    : AppTheme.cardShadow,
              ),
              child: Center(
                child: ScaleTransition(
                  scale: _badgeScale,
                  child: rank <= 3
                      ? Icon(rankIcon, color: rankColor, size: 28)
                      : Text(
                          '#$rank',
                          style: AppTheme.labelLarge.copyWith(
                            color: rankColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),

            // Team info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        team['emoji'] ?? '👥',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      // Crown emoji for winner (rank 1)
                      if (rank == 1) ...[
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glow background
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: AppTheme.glowShadow(const Color(0xFFFFD700)),
                              ),
                            ),
                            // Crown emoji
                            const Text('👑', style: TextStyle(fontSize: 28)),
                          ],
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: rank <= 3
                            ? GradientText(
                                text: team['team_name'] ?? 'Team',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    rankColor,
                                    rankColor.withValues(alpha: 0.7),
                                  ],
                                ),
                              )
                            : Text(
                                team['team_name'] ?? 'Team',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      // Winner badge for rank 1
                      if (rank == 1)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'WINNER',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${team['checkpoints_completed'] ?? 0}/$totalCheckpoints checkpoints',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Points and bonus button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bonus points button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showBonusPointsDialog(team);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppTheme.warning,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                // Points display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.warning.withValues(alpha: 0.2),
                        AppTheme.warning.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppTheme.warning, size: 20),
                      const SizedBox(width: 4),
                      TweenAnimationBuilder<int>(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        tween: IntTween(
                          begin: 0,
                          end: team['total_points'] ?? 0,
                        ),
                        builder: (context, value, child) {
                          return Text(
                            '$value',
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTab() {
    if (pendingSubmissions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'All caught up!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No pending submissions to review',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingSubmissions.length,
      itemBuilder: (context, index) {
        final submission = pendingSubmissions[index];
        return _buildSubmissionCard(submission);
      },
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final task = submission['tasks'];
    final team = submission['teams'];
    final participant = submission['participants'];
    final isPhoto = submission['submission_type'] == 'photo';

    return Card(
      color: const Color(0xFF1A2332),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  team?['emoji'] ?? '👥',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team?['team_name'] ?? 'Team',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'by ${participant?['name'] ?? 'Unknown'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${task?['points'] ?? 0} pts',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Task title
            Text(
              task?['title'] ?? 'Task',
              style: const TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            
            // Photo preview (if photo task)
            if (isPhoto && submission['photo_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: submission['photo_url'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            
            // Quiz answer (if quiz task)
            if (submission['submission_type'] == 'quiz')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.quiz, color: Colors.purple),
                    const SizedBox(width: 12),
                    Text(
                      'Answer: ${submission['quiz_answer'] ?? 'N/A'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectSubmission(submission),
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
                    onPressed: () => _approveSubmission(submission),
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
}
