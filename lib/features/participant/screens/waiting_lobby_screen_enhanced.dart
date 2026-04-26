import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';

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
  bool _isLoading = true;
  RealtimeChannel? _participantsChannel;
  RealtimeChannel? _teamAssignmentChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    _loadInitialData();
    
    // Simulate loading completion
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _loadInitialData() async {
    // Simulate initial data loading
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeListeners() {
    _participantsChannel = Supabase.instance.client
        .channel('public:activities_${widget.activity.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'participants',
          table: 'participants',
          callback: (payload) {
            if (mounted) {
              final newParticipant = ParticipantModel.fromJson(payload.newRecord);
              setState(() {
                _participants.add(newParticipant);
                _participantCount++;
              });
            }
          },
        )
        .subscribe();

    _teamAssignmentChannel = Supabase.instance.client
        .channel('public:activities_${widget.activity.id}_teams')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'teams',
          callback: (payload) {
            if (mounted) {
              setState(() => _isCheckingTeams = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() => _isCheckingTeams = false);
                }
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _participantsChannel?.unsubscribe();
    _teamAssignmentChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E3A8A),
                  Color(0xFF2E5266),
                ],
              ),
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            FullScreenLoadingOverlay(
              isLoading: _isLoading,
              loadingMessage: 'Joining activity...',
              child: _buildWaitingContent(context),
            ),
          
          // Main content
          if (!_isLoading)
            _buildWaitingContent(context),
        ],
      ),
    );
  }

  Widget _buildWaitingContent(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header with Google Fonts
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiting Lobby',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.activity.name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Lottie animation
                Lottie.asset(
                  'assets/animations/waiting.json',
                  width: 80,
                  height: 80,
                  repeat: true,
                  animate: true,
                ),
              ],
            ),
            
            const Spacer(),
            
            // Participant count with shimmer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Participants Joined',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _isCheckingTeams
                      ? Shimmer.fromColors(
                          baseColor: Colors.white.withOpacity(0.3),
                          highlightColor: Colors.white.withOpacity(0.6),
                          child: Container(
                            width: 60,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : Text(
                          '$_participantCount',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ],
              ),
            ),
            
            const Spacer(flex: 2),
            
            // Team assignment status
            if (_isCheckingTeams)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Assigning teams...',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            
            const Spacer(),
            
            // Participants list with shimmer
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Participants',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _participants.isEmpty
                          ? _buildEmptyParticipantsList()
                          : _buildParticipantsList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyParticipantsList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty.json',
            width: 120,
            height: 120,
            repeat: true,
            animate: true,
          ),
          const SizedBox(height: 16),
          Text(
            'No participants yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Avatar with shimmer loading
              Shimmer.fromColors(
                baseColor: Colors.white.withOpacity(0.2),
                highlightColor: Colors.white.withOpacity(0.4),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Participant info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.name ?? 'Anonymous',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Joined ${_formatTime(participant.joinedAt)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime!);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}

/// Full screen loading overlay widget
class FullScreenLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;

  const FullScreenLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset(
                      'assets/animations/loading.json',
                      width: 100,
                      height: 100,
                      repeat: true,
                      animate: true,
                    ),
                    if (loadingMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        loadingMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
