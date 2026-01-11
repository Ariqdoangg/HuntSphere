import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class _WaitingLobbyScreenState extends State<WaitingLobbyScreen> {
  int _participantCount = 0;
  List<ParticipantModel> _participants = [];
  bool _isCheckingTeams = false;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    // Check teams immediately on load
    _checkTeamAssignment();
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
      // Check if current participant has been assigned a team
      final participantData = await Supabase.instance.client
          .from('participants')
          .select('team_id')
          .eq('id', widget.participant.id!)
          .single();

      if (participantData['team_id'] != null && mounted) {
        // Team assigned! Navigate to team reveal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TeamRevealScreen(
              participant: widget.participant,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teams not formed yet. Keep waiting...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking team assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingTeams = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Lobby'),
        backgroundColor: const Color(0xFF0A1628),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadParticipants();
              _checkTeamAssignment();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Activity Info Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00D9FF).withValues(alpha: 0.2),
                    const Color(0xFF0A1628),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    size: 48,
                    color: Color(0xFF00D9FF),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.activity.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Join Code: ${widget.activity.joinCode}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00D9FF),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Participant Count
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people,
                    size: 48,
                    color: Color(0xFF00D9FF),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_participantCount',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D9FF),
                        ),
                      ),
                      const Text(
                        'Participants',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Status Message
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for facilitator to start the activity...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Check Teams Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCheckingTeams ? null : _checkTeamAssignment,
                  icon: _isCheckingTeams
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _isCheckingTeams ? 'Checking...' : 'Check if Teams Formed',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Participants Grid
            Expanded(
              child: _participants.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00D9FF),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _participants.length,
                      itemBuilder: (context, index) {
                        final participant = _participants[index];
                        final isCurrentUser = participant.id == widget.participant.id;
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2332),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrentUser
                                  ? const Color(0xFF00D9FF)
                                  : Colors.white24,
                              width: isCurrentUser ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Selfie
                              if (participant.selfieUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.network(
                                    participant.selfieUrl!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Color(0xFF00D9FF),
                                        child: Icon(
                                          Icons.person,
                                          size: 30,
                                          color: Colors.black,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Color(0xFF00D9FF),
                                  child: Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.black,
                                  ),
                                ),
                              const SizedBox(height: 8),

                              // Name
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  participant.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCurrentUser
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isCurrentUser
                                        ? const Color(0xFF00D9FF)
                                        : Colors.white,
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
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00D9FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
