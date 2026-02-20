import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';
import 'team_reveal_screen.dart';
import '../../../core/widgets/huntsphere_watermark.dart';

class WaitingLobbyScreen extends StatefulWidget {
  final ActivityModel activity;
  final ParticipantModel participant;

  const WaitingLobbyScreen({
    super.key,
    required this.activity,
    required this.participant,
  });

  @override
  State<WaitingLobbyScreen> createState() => _WaitingLobbyScreenState();
}

class _WaitingLobbyScreenState extends State<WaitingLobbyScreen>
    with SingleTickerProviderStateMixin {
  int _participantCount = 0;
  List<ParticipantModel> _participants = [];
  bool _isCheckingTeams = false;
  RealtimeChannel? _participantsChannel;
  RealtimeChannel? _teamAssignmentChannel;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadParticipants();
    _subscribeToParticipants();
    _subscribeToTeamAssignment();
  }

  void _subscribeToParticipants() {
    _participantsChannel = Supabase.instance.client
        .channel('waiting_lobby_participants_${widget.activity.id}')
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
            debugPrint('📢 Participant update: ${payload.eventType}');
            _loadParticipants();
          },
        )
        .subscribe();
  }

  void _subscribeToTeamAssignment() {
    _teamAssignmentChannel = Supabase.instance.client
        .channel('waiting_lobby_team_${widget.participant.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.participant.id,
          ),
          callback: (payload) {
            debugPrint('📢 Team assignment update: ${payload.newRecord}');
            final newRecord = payload.newRecord;
            if (newRecord['team_id'] != null && mounted) {
              _navigateToTeamReveal();
            }
          },
        )
        .subscribe();
  }

  void _navigateToTeamReveal() {
    debugPrint('🎯 Navigating to team reveal...');
    debugPrint('👤 Participant ID: ${widget.participant.id}');
    debugPrint('🎮 Activity ID: ${widget.participant.activityId}');

    // Validate required data before navigation
    if (widget.participant.id == null) {
      debugPrint('❌ Cannot navigate: Participant ID is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Participant ID is missing. Please rejoin the activity.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.participant.activityId.isEmpty) {
      debugPrint('❌ Cannot navigate: Activity ID is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Activity ID is missing. Please rejoin the activity.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('✅ Validation passed - proceeding to TeamRevealScreen');

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TeamRevealScreen(participant: widget.participant),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
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
        _participantCount = _participants.length;
      });
    } catch (e) {
      debugPrint('Error loading participants: $e');
    }
  }

  Future<void> _checkTeamAssignment() async {
    setState(() => _isCheckingTeams = true);

    try {
      final participantData = await Supabase.instance.client
          .from('participants')
          .select('team_id')
          .eq('id', widget.participant.id!)
          .single();

      if (participantData['team_id'] != null && mounted) {
        _navigateToTeamReveal();
      } else {
        if (mounted) {
          _showSnackBar('Teams not formed yet. Keep waiting...');
        }
      }
    } catch (e) {
      debugPrint('Error checking team assignment: $e');
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingTeams = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.primaryBlue,
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
    _pulseController.dispose();
    _participantsChannel?.unsubscribe();
    _teamAssignmentChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      appBar: AppBar(
        title: const Text('Waiting Lobby'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
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
            onPressed: () {
              _loadParticipants();
              _checkTeamAssignment();
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: AppTheme.spacingS),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Activity Info Card
                _buildActivityHeader(),

                // Participant Count
                _buildParticipantCount(),

                const SizedBox(height: AppTheme.spacingM),

                // Status Message
                _buildStatusMessage(),

                const SizedBox(height: AppTheme.spacingM),

                // Check Teams Button
                _buildCheckTeamsButton(),

                const SizedBox(height: AppTheme.spacingL),

                // Participants Grid
                Expanded(child: _buildParticipantsGrid()),
              ],
            ),
          ),
          // HuntSphere watermark for screenshots
          const HuntSphereWatermark(
            alignment: Alignment.topRight,
            opacity: 0.6,
          ),
        ],
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
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      size: 40,
                      color: AppTheme.warning,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              widget.activity.name,
              style: AppTheme.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
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
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    widget.activity.joinCode,
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.accent,
                      letterSpacing: 3,
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

  Widget _buildParticipantCount() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: EliteCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.people_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppTheme.spacingL),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_participantCount',
                  style: AppTheme.displayMedium.copyWith(
                    color: AppTheme.accent,
                  ),
                ),
                Text(
                  'Participants',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.success.withValues(alpha: 0.15),
            AppTheme.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Pulsing dot
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.success
                          .withValues(alpha: _pulseAnimation.value * 0.5),
                      blurRadius: 8,
                      spreadRadius: 2 * _pulseAnimation.value,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live • Listening for game start',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You will be automatically redirected when the game starts',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTeamsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: EliteButton(
        label: _isCheckingTeams ? 'Checking...' : 'Check if Teams Formed',
        icon: Icons.check_circle_rounded,
        onPressed: _isCheckingTeams ? null : _checkTeamAssignment,
        isLoading: _isCheckingTeams,
      ),
    );
  }

  Widget _buildParticipantsGrid() {
    if (_participants.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : (constraints.maxWidth > 400 ? 3 : 2);
        return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        final isCurrentUser = participant.id == widget.participant.id;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            // Clamp value to ensure it's always between 0.0 and 1.0
            final clampedValue = value.clamp(0.0, 1.0);
            return Transform.scale(
              scale: clampedValue,
              child: Opacity(opacity: clampedValue, child: child),
            );
          },
          child: EliteCard(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            showBorder: true,
            gradient: isCurrentUser
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryBlue.withValues(alpha: 0.2),
                      AppTheme.primaryPurple.withValues(alpha: 0.1),
                    ],
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Selfie
                if (participant.selfieUrl != null)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isCurrentUser
                          ? Border.all(color: AppTheme.accent, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: CachedNetworkImage(
                        imageUrl: participant.selfieUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          return _buildDefaultAvatar(isCurrentUser);
                        },
                      ),
                    ),
                  )
                else
                  _buildDefaultAvatar(isCurrentUser),
                const SizedBox(height: AppTheme.spacingS),

                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    participant.name,
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight:
                          isCurrentUser ? FontWeight.bold : FontWeight.w500,
                      color:
                          isCurrentUser ? AppTheme.accent : AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // "You" Badge
                if (isCurrentUser) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      'YOU',
                      style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
      },
    );
  }

  Widget _buildDefaultAvatar(bool isCurrentUser) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
        border:
            isCurrentUser ? Border.all(color: AppTheme.accent, width: 2) : null,
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 30,
        color: Colors.white,
      ),
    );
  }
}
