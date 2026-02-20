import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';
import 'package:huntsphere/services/audio_service.dart';
import 'facilitator_leaderboard_screen.dart';

class FacilitatorLobbyScreen extends StatefulWidget {
  final ActivityModel activity;

  const FacilitatorLobbyScreen({
    super.key,
    required this.activity,
  });

  @override
  State<FacilitatorLobbyScreen> createState() => _FacilitatorLobbyScreenState();
}

class _FacilitatorLobbyScreenState extends State<FacilitatorLobbyScreen>
    with SingleTickerProviderStateMixin {
  List<ParticipantModel> _participants = [];
  RealtimeChannel? _channel;
  bool _isStarting = false;
  int _expectedTeams = 0;

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
    _loadParticipants();
    _subscribeToUpdates();
    _animationController.forward();
  }

  Future<void> _loadParticipants() async {
    try {
      final response = await Supabase.instance.client
          .from('participants')
          .select()
          .eq('activity_id', widget.activity.id!)
          .order('joined_at', ascending: true);

      setState(() {
        _participants = (response as List)
            .map((json) => ParticipantModel.fromJson(json))
            .toList();
        _expectedTeams = (_participants.length / 4).ceil();
      });
    } catch (e) {
      debugPrint('Error loading participants: $e');
    }
  }

  void _subscribeToUpdates() {
    _channel = Supabase.instance.client
        .channel('facilitator_lobby_${widget.activity.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: widget.activity.id,
          ),
          callback: (payload) {
            _loadParticipants();
          },
        )
        .subscribe();
  }

  Future<void> _startActivity() async {
    if (_participants.length < 3) {
      _showSnackBar('Need at least 3 participants to start', isError: true);
      return;
    }

    setState(() => _isStarting = true);
    HapticFeedback.mediumImpact();

    try {
      final supabase = Supabase.instance.client;

      // 1. Update activity status to 'active' (use UTC to avoid timezone issues)
      final now = DateTime.now().toUtc().toIso8601String();
      await supabase
          .from('activities')
          .update({
            'status': 'active',
            'started_at': now,
            'game_started_at': now,
          })
          .eq('id', widget.activity.id!);

      // 2. Form teams - distribute participants evenly
      final participantIds = _participants.map((p) => p.id!).toList();
      participantIds.shuffle(); // Randomize

      // UPDATED: Smart team calculation with optimal 3-4 person teams
      final totalParticipants = participantIds.length;
      int teamCount;

      // Determine optimal team count based on participant count
      // Goal: Maintain 3-4 person teams, avoid single-person teams
      if (totalParticipants == 3) {
        // Special case: 1 team (collaborative mode, no competition)
        teamCount = 1;
      } else if (totalParticipants >= 4 && totalParticipants <= 5) {
        // 4-5 participants: 2 teams (2-2 or 3-2)
        teamCount = 2;
      } else if (totalParticipants >= 6 && totalParticipants <= 8) {
        // 6-8 participants: 2 teams (3-3, 4-3, or 4-4)
        teamCount = 2;
      } else if (totalParticipants >= 9 && totalParticipants <= 12) {
        // 9-12 participants: 3 teams (3-4 orang each)
        teamCount = 3;
      } else if (totalParticipants >= 13 && totalParticipants <= 16) {
        // 13-16 participants: 4 teams (3-4 orang each)
        teamCount = 4;
      } else {
        // 17+ participants: ~4 people per team
        teamCount = (totalParticipants / 4).round();
        // Ensure we don't create teams smaller than 3
        if (totalParticipants / teamCount < 3) {
          teamCount = (totalParticipants / 3).ceil();
        }
      }

      debugPrint('📊 Creating $teamCount teams for $totalParticipants participants');

      // Create teams and assign participants with balanced distribution
      int participantIndex = 0;

      for (int i = 0; i < teamCount; i++) {
        // Calculate how many participants for THIS team
        final remainingParticipants = totalParticipants - participantIndex;
        final remainingTeams = teamCount - i;

        // Distribute remainder evenly (not all to last team!)
        final teamSize = (remainingParticipants / remainingTeams).ceil();

        // Create team
        final teamResult = await supabase
            .from('teams')
            .insert({
              'activity_id': widget.activity.id,
              'team_number': i + 1,
              'team_name': 'Team ${i + 1}',
              'total_points': 0,
            })
            .select()
            .single();

        final teamId = teamResult['id'];

        // Assign participants to this team (balanced distribution)
        for (int j = 0; j < teamSize && participantIndex < totalParticipants; j++) {
          await supabase
              .from('participants')
              .update({'team_id': teamId})
              .eq('id', participantIds[participantIndex]);

          participantIndex++;
        }

        debugPrint('✅ Team ${i + 1} assigned $teamSize participants');
      }

      if (mounted) {
        // Play activity start sound and haptic feedback
        await AudioService().play('activity_start');
        HapticFeedback.heavyImpact();
        _showSnackBar('Activity started! $teamCount teams formed');

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                FacilitatorLeaderboardScreen(
              activityId: widget.activity.id!,
              activityName: widget.activity.name,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error starting activity: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingM),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _participants.length >= 3;

    return EliteScaffold(
      appBar: AppBar(
        title: const Text('Lobby Control'),
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
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Icon(Icons.refresh, size: 20),
            ),
            onPressed: _loadParticipants,
          ),
          const SizedBox(width: AppTheme.spacingS),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Activity Info Card
              _buildActivityHeader(),

              // Stats Row
              _buildStatsRow(),

              const SizedBox(height: AppTheme.spacingM),

              // Status Message
              _buildStatusMessage(canStart),

              const SizedBox(height: AppTheme.spacingM),

              // Participants Grid
              Expanded(child: _buildParticipantsGrid()),

              // Start Button
              _buildStartButton(canStart),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppTheme.spacingM),
      child: EliteCard(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.15),
            AppTheme.primaryPurple.withValues(alpha: 0.1),
            AppTheme.backgroundCard,
          ],
        ),
        child: Column(
          children: [
            Text(
              widget.activity.name,
              style: AppTheme.headingLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.vpn_key_rounded,
                    color: AppTheme.accent,
                    size: 18,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    widget.activity.joinCode,
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.accent,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.people_rounded,
              label: 'Participants',
              value: '${_participants.length}',
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: _StatCard(
              icon: Icons.groups_rounded,
              label: 'Expected Teams',
              value: '$_expectedTeams',
              color: AppTheme.primaryPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(bool canStart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (canStart ? AppTheme.success : AppTheme.warning)
                .withValues(alpha: 0.15),
            (canStart ? AppTheme.success : AppTheme.warning)
                .withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: (canStart ? AppTheme.success : AppTheme.warning)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (canStart ? AppTheme.success : AppTheme.warning)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(
              canStart ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: canStart ? AppTheme.success : AppTheme.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              canStart
                  ? 'Ready to start! Click the button below.'
                  : 'Waiting for more participants (minimum 3)...',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid() {
    if (_participants.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundCard,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_outline_rounded,
                    size: 48,
                    color: AppTheme.textMuted.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'No participants yet',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Share the join code with participants',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textDisabled),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 5 : (constraints.maxWidth > 400 ? 4 : 3);
        return GridView.builder(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: _participants.length,
          itemBuilder: (context, index) {
            final participant = _participants[index];
            return _ParticipantCard(participant: participant, index: index);
          },
        );
      },
    );
  }

  Widget _buildStartButton(bool canStart) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingM,
          AppTheme.spacingS,
          AppTheme.spacingM,
          AppTheme.spacingM,
        ),
        child: EliteButton(
          label: 'Start Activity & Form Teams',
          icon: Icons.play_arrow_rounded,
          onPressed: canStart && !_isStarting ? _startActivity : null,
          isLoading: _isStarting,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return EliteCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: AppTheme.displayMedium.copyWith(
              color: color,
              fontSize: 32,
            ),
          ),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final ParticipantModel participant;
  final int index;

  const _ParticipantCard({
    required this.participant,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: EliteCard(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Selfie
            if (participant.selfieUrl != null)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.network(
                    participant.selfieUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar();
                    },
                  ),
                ),
              )
            else
              _buildDefaultAvatar(),
            const SizedBox(height: AppTheme.spacingS),

            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                participant.name,
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Join time
            if (participant.joinedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTime(participant.joinedAt!),
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textDisabled,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 30,
        color: Colors.white,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}
