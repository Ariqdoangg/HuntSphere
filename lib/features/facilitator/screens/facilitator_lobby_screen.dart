import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/features/shared/models/activity_model.dart';
import 'package:huntsphere/features/shared/models/participant_model.dart';

class FacilitatorLobbyScreen extends StatefulWidget {
  final ActivityModel activity;

  const FacilitatorLobbyScreen({
    super.key,
    required this.activity,
  });

  @override
  State<FacilitatorLobbyScreen> createState() => _FacilitatorLobbyScreenState();
}

class _FacilitatorLobbyScreenState extends State<FacilitatorLobbyScreen> {
  List<ParticipantModel> _participants = [];
  RealtimeChannel? _channel;
  bool _isStarting = false;
  int _expectedTeams = 0;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    _subscribeToUpdates();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 3 participants to start'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    try {
      // Call start_activity function
      final result = await Supabase.instance.client
          .rpc('start_activity', params: {'p_activity_id': widget.activity.id});

      if (mounted) {
        if (result[0]['success'] == true) {
          final teamsFormed = result[0]['teams_formed'];
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activity started! $teamsFormed teams formed'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back or to game monitoring screen
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result[0]['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting activity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _participants.length >= 3;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby Control'),
        backgroundColor: const Color(0xFF0A1628),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadParticipants,
          ),
        ],
      ),
      body: Column(
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
                Text(
                  widget.activity.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D9FF),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.people,
                    label: 'Participants',
                    value: '${_participants.length}',
                    color: const Color(0xFF00D9FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.groups,
                    label: 'Expected Teams',
                    value: '$_expectedTeams',
                    color: Colors.purple,
                  ),
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
              color: canStart 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canStart 
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  canStart ? Icons.check_circle : Icons.info_outline,
                  color: canStart ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    canStart
                        ? 'Ready to start! Click the button below.'
                        : 'Waiting for more participants (minimum 3)...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Participants Grid
          Expanded(
            child: _participants.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.white24,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No participants yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white54,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Share the join code with participants',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final participant = _participants[index];
                      return _ParticipantCard(participant: participant);
                    },
                  ),
          ),

          // Start Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: canStart && !_isStarting ? _startActivity : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: _isStarting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Start Activity & Form Teams',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final ParticipantModel participant;

  const _ParticipantCard({required this.participant});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selfie
          if (participant.selfieUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.network(
                participant.selfieUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF00D9FF),
                    child: Icon(Icons.person, size: 30, color: Colors.black),
                  );
                },
              ),
            )
          else
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFF00D9FF),
              child: Icon(Icons.person, size: 30, color: Colors.black),
            ),
          const SizedBox(height: 8),

          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              participant.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
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
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ),
        ],
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
