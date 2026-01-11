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
      // Refresh participant to get team_id and activity_id
      final participantData = await Supabase.instance.client
          .from('participants')
          .select('team_id, activity_id')
          .eq('id', widget.participant.id!)
          .single();

      final teamId = participantData['team_id'];
      _activityId = participantData['activity_id'];

      if (teamId == null) {
        throw Exception('Not assigned to a team yet');
      }

      // Get team info with members
      final teamInfo = await Supabase.instance.client
          .rpc('get_team_info', params: {'p_team_id': teamId})
          .single();

      setState(() {
        _teamData = teamInfo;
        _isLoading = false;
      });

      // Start reveal animation
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading team: $e')),
        );
      }
    }
  }

  void _startGame() {
    if (_teamData == null || _activityId == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameMapScreen(
          participantId: widget.participant.id!,
          teamId: _teamData!['team_id'],
          activityId: _activityId!,
        ),
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

    final teamColor = Color(
      int.parse(_teamData!['team_color'].substring(1), radix: 16) + 0xFF000000,
    );
    final members = _teamData!['members'] as List<dynamic>;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A1628),
              teamColor.withValues(alpha: 0.3),
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
                    color: teamColor.withValues(alpha: 0.3),
                    border: Border.all(
                      color: teamColor,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _teamData!['team_emoji'],
                        style: const TextStyle(fontSize: 80),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _teamData!['team_name'],
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
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isCurrentUser = member['id'] == widget.participant.id;
                      
                      return _TeammateCard(
                        name: member['name'],
                        selfieUrl: member['selfie_url'],
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
                  color: teamColor.withValues(alpha: 0.3),
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
          if (selfieUrl != null)
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
                    backgroundColor: teamColor.withValues(alpha: 0.3),
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
              backgroundColor: teamColor.withValues(alpha: 0.3),
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
