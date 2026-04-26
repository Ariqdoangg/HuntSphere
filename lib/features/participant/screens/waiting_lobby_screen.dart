import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';
import 'team_reveal_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Waiting Lobby',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.refresh, size: 20, color: Colors.white70),
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
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A0E1A), Color(0xFF0D1B2A), Color(0xFF0A0E1A)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildActivityHeader(),
                  _buildParticipantCount(),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildStatusMessage(),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildCheckTeamsButton(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildParticipantsGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingS,
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.activity.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound - 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.vpn_key_rounded, color: Color(0xFF4A90E2), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'CODE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.activity.joinCode,
                    style: const TextStyle(
                      color: Color(0xFF4A90E2),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCount() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(AppTheme.radiusRound - 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '$_participantCount Participants',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.success
                          .withValues(alpha: _pulseAnimation.value * 0.6),
                      blurRadius: 6,
                      spreadRadius: 2 * _pulseAnimation.value,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: AppTheme.spacingM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live • Waiting for game start',
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "You'll be redirected automatically",
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTeamsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: GestureDetector(
        onTap: _isCheckingTeams ? null : _checkTeamAssignment,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: _isCheckingTeams
                ? null
                : const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                  ),
            color: _isCheckingTeams ? Colors.white12 : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: _isCheckingTeams
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Check if Teams Formed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsGrid() {
    if (_participants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PARTICIPANTS',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '$_participantCount joined',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _participants.asMap().entries.map((entry) {
                  final index = entry.key;
                  final participant = entry.value;
                  final isCurrentUser = participant.id == widget.participant.id;

                  final Widget avatar = participant.selfieUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: CachedNetworkImage(
                            imageUrl: participant.selfieUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 52,
                              height: 52,
                              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildSmallAvatar(isCurrentUser, size: 52),
                          ),
                        )
                      : _buildSmallAvatar(isCurrentUser, size: 52);

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 200 + (index * 30)),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      final clampedValue = value.clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: clampedValue,
                        child: Opacity(opacity: clampedValue, child: child),
                      );
                    },
                    child: Container(
                      width: itemWidth,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? const Color(0xFF4A90E2).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrentUser
                              ? const Color(0xFF4A90E2).withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          avatar,
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              participant.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
        ],
      ),
    );
  }

  Widget _buildSmallAvatar(bool isCurrentUser, {double size = 44}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
        ),
        shape: BoxShape.circle,
        border: isCurrentUser
            ? Border.all(color: AppTheme.accent, width: 2)
            : null,
      ),
      child: Icon(Icons.person_rounded, size: size * 0.5, color: Colors.white),
    );
  }

  Widget _buildDefaultAvatar(bool isCurrentUser) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
        ),
        shape: BoxShape.circle,
        border: isCurrentUser
            ? Border.all(color: AppTheme.accent, width: 2.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.person_rounded, size: 34, color: Colors.white),
    );
  }
}
