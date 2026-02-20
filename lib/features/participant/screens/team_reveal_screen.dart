import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';
import 'game_map_screen.dart';

class TeamRevealScreen extends StatefulWidget {
  final ParticipantModel participant;

  const TeamRevealScreen({
    super.key,
    required this.participant,
  });

  @override
  State<TeamRevealScreen> createState() => _TeamRevealScreenState();
}

class _TeamRevealScreenState extends State<TeamRevealScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _teamData;
  String? _activityId;
  String? _teamId; // Store team ID separately for safety
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadTeamData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  Future<void> _loadTeamData() async {
    try {
      debugPrint('🔍 Loading team data...');
      debugPrint('👤 Participant ID: ${widget.participant.id}');
      
      // Check participant ID first
      if (widget.participant.id == null || widget.participant.id!.isEmpty) {
        throw Exception('Participant ID is missing');
      }

      // Refresh participant to get team_id and activity_id
      final participantData = await Supabase.instance.client
          .from('participants')
          .select('team_id, activity_id')
          .eq('id', widget.participant.id!)
          .single();

      debugPrint('📊 Participant data fetched: $participantData');

      // Safely extract team_id (could be UUID, convert to String)
      final rawTeamId = participantData['team_id'];
      final teamId = rawTeamId?.toString();
      
      // Safely extract activity_id
      final rawActivityId = participantData['activity_id'];
      final activityId = rawActivityId?.toString();

      debugPrint('🎯 Raw Team ID: $rawTeamId (type: ${rawTeamId.runtimeType})');
      debugPrint('🎯 Raw Activity ID: $rawActivityId (type: ${rawActivityId.runtimeType})');
      debugPrint('🎯 Converted Team ID: $teamId');
      debugPrint('🎯 Converted Activity ID: $activityId');

      // Use fallback to widget.participant.activityId if database fetch fails
      _activityId = activityId ?? widget.participant.activityId;
      _teamId = teamId;

      debugPrint('✅ Final Team ID: $_teamId, Activity ID: $_activityId');

      if (_teamId == null || _teamId!.isEmpty) {
        throw Exception('Not assigned to a team yet');
      }

      if (_activityId == null || _activityId!.isEmpty) {
        throw Exception('Activity ID is missing');
      }

      // Get team info with members
      final teamInfo = await Supabase.instance.client
          .rpc('get_team_info', params: {'p_team_id': _teamId})
          .single();

      debugPrint('👥 Team info fetched: $teamInfo');
      debugPrint('👥 Team info type: ${teamInfo.runtimeType}');

      setState(() {
        _teamData = teamInfo;
        _isLoading = false;
      });

      // Start reveal animation
      _animationController.forward();
    } catch (e) {
      debugPrint('❌ Error loading team data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading team: $e')),
        );
      }
    }
  }

  void _startGame() {
    debugPrint('🎮 ====== STARTING GAME ======');
    debugPrint('📊 Team data: $_teamData');
    debugPrint('🎯 Activity ID: $_activityId');
    debugPrint('🏷️ Team ID (stored): $_teamId');
    debugPrint('👤 Participant ID: ${widget.participant.id}');

    // === VALIDATION ===
    
    // 1. Check participant ID
    final participantId = widget.participant.id;
    if (participantId == null || participantId.isEmpty) {
      debugPrint('❌ FAIL: Participant ID is null or empty!');
      _showError('Participant ID is missing. Please rejoin the activity.');
      return;
    }

    // 2. Check activity ID
    final activityId = _activityId;
    if (activityId == null || activityId.isEmpty) {
      debugPrint('❌ FAIL: Activity ID is null or empty!');
      _showError('Activity ID is missing. Please try again.');
      return;
    }

    // 3. Check team ID (use stored _teamId, not from _teamData)
    final teamId = _teamId;
    if (teamId == null || teamId.isEmpty) {
      debugPrint('❌ FAIL: Team ID is null or empty!');
      _showError('Team ID is missing. Please try again.');
      return;
    }

    // 4. Check team data exists (for display purposes)
    if (_teamData == null) {
      debugPrint('❌ FAIL: Team data is null!');
      _showError('Team data is missing. Please try again.');
      return;
    }

    debugPrint('✅ ====== ALL VALIDATIONS PASSED ======');
    debugPrint('   ➡️ participantId: $participantId');
    debugPrint('   ➡️ teamId: $teamId');
    debugPrint('   ➡️ activityId: $activityId');

    // Navigate to GameMapScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameMapScreen(
          participantId: participantId,
          teamId: teamId,
          activityId: activityId,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00D9FF)),
              SizedBox(height: 24),
              Text(
                'Forming teams...',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_teamData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Team not found',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Safely parse team color
    Color teamColor;
    try {
      final colorString = _teamData!['team_color']?.toString() ?? '#00D9FF';
      final colorHex = colorString.replaceFirst('#', '');
      teamColor = Color(int.parse(colorHex, radix: 16) + 0xFF000000);
    } catch (e) {
      debugPrint('⚠️ Error parsing team color: $e');
      teamColor = const Color(0xFF00D9FF); // Default cyan
    }

    final members = (_teamData!['members'] as List<dynamic>?) ?? [];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A1628),
              teamColor.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // "Your Team" Title
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  'Your Team',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Team Badge
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: teamColor.withOpacity(0.3),
                    border: Border.all(
                      color: teamColor,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _teamData!['team_emoji']?.toString() ?? '🎯',
                        style: const TextStyle(fontSize: 80),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _teamData!['team_name']?.toString() ?? 'Team',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: teamColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // "Your Teammates" Header
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Your Teammates',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Teammates Grid
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: members.isEmpty
                      ? const Center(
                          child: Text(
                            'No teammates yet',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index] as Map<String, dynamic>? ?? {};
                            final memberId = member['id']?.toString();
                            final memberName = member['name']?.toString() ?? 'Unknown';
                            final selfieUrl = member['selfie_url']?.toString();
                            final isCurrentUser = memberId == widget.participant.id;
                            
                            return _TeammateCard(
                              name: memberName,
                              selfieUrl: selfieUrl,
                              isCurrentUser: isCurrentUser,
                              teamColor: teamColor,
                            );
                          },
                        ),
                ),
              ),

              // Let's Go Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teamColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      '🚀 Let\'s Go!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeammateCard extends StatelessWidget {
  final String name;
  final String? selfieUrl;
  final bool isCurrentUser;
  final Color teamColor;

  const _TeammateCard({
    required this.name,
    required this.selfieUrl,
    required this.isCurrentUser,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentUser ? teamColor : Colors.white24,
          width: isCurrentUser ? 3 : 1,
        ),
        boxShadow: isCurrentUser
            ? [
                BoxShadow(
                  color: teamColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selfie
          if (selfieUrl != null && selfieUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.network(
                selfieUrl!,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return CircleAvatar(
                    radius: 40,
                    backgroundColor: teamColor.withOpacity(0.3),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: teamColor,
                    ),
                  );
                },
              ),
            )
          else
            CircleAvatar(
              radius: 40,
              backgroundColor: teamColor.withOpacity(0.3),
              child: Icon(
                Icons.person,
                size: 40,
                color: teamColor,
              ),
            ),
          const SizedBox(height: 12),

          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                color: isCurrentUser ? teamColor : Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // "You" Badge
          if (isCurrentUser) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'YOU',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
