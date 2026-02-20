import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huntsphere/providers/leaderboard_provider.dart';
import 'package:huntsphere/services/realtime_service.dart';
import 'package:huntsphere/core/theme/app_theme.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String activityId;
  final String? currentTeamId;

  const LeaderboardScreen({
    super.key,
    required this.activityId,
    this.currentTeamId,
  });

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with TickerProviderStateMixin {
  int totalCheckpoints = 0;

  @override
  void initState() {
    super.initState();
    _loadTotalCheckpoints();
  }

  Future<void> _loadTotalCheckpoints() async {
    final count = await ref.read(totalCheckpointsProvider(widget.activityId).future);
    if (mounted) {
      setState(() {
        totalCheckpoints = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the real-time leaderboard stream
    final leaderboardAsync = ref.watch(leaderboardStreamProvider(widget.activityId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EliteLogo(size: 28, showGlow: false),
            const SizedBox(width: 10),
            GradientText(
              text: 'HuntSphere Leaderboard',
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
        backgroundColor: const Color(0xFF0A1628),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(leaderboardStreamProvider(widget.activityId));
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0A1628),
      body: leaderboardAsync.when(
        data: (teams) => _buildContent(teams),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(error.toString()),
      ),
    );
  }

  Widget _buildContent(List<LeaderboardEntry> teams) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardStreamProvider(widget.activityId));
      },
      child: Column(
        children: [
          // Header stats
          _buildHeader(teams.length),

          // Team rankings
          Expanded(
            child: teams.isEmpty
                ? const Center(
                    child: Text(
                      'No teams yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      return _buildTeamCard(teams[index], index + 1);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(leaderboardStreamProvider(widget.activityId));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int teamCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.3),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Column(
        children: [
          const Text(
            '',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          const Text(
            'LIVE RANKINGS',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$teamCount Teams - $totalCheckpoints Checkpoints',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Real-time updates',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(LeaderboardEntry team, int rank) {
    final isCurrentTeam = team.id == widget.currentTeamId;
    final isWinner = rank == 1 && team.totalPoints > 0;
    final checkpointsCompleted = team.checkpointsCompleted;
    final progress = totalCheckpoints > 0
        ? checkpointsCompleted / totalCheckpoints
        : 0.0;

    Color rankColor;
    IconData? rankIcon;

    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey.shade400;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = Colors.brown.shade400;
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.white54;
        rankIcon = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isCurrentTeam
            ? LinearGradient(
                colors: [
                  const Color(0xFF00D9FF).withValues(alpha: 0.3),
                  const Color(0xFF00D9FF).withValues(alpha: 0.1),
                ],
              )
            : null,
        color: isCurrentTeam ? null : const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: isCurrentTeam
            ? Border.all(color: const Color(0xFF00D9FF), width: 2)
            : isWinner
                ? Border.all(color: Colors.amber, width: 2)
                : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Rank
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: rankIcon != null
                        ? Icon(rankIcon, color: rankColor, size: 28)
                        : Text(
                            '#$rank',
                            style: TextStyle(
                              color: rankColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Team info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            team.emoji ?? '',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              team.teamName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isCurrentTeam)
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 1500),
                              tween: Tween(begin: 1.0, end: 1.05),
                              curve: Curves.easeInOut,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00D9FF).withValues(alpha: 0.5),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onEnd: () {
                                // Reverse animation for continuous pulse
                                if (mounted) {
                                  Future.delayed(Duration.zero, () {
                                    setState(() {});
                                  });
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$checkpointsCompleted / $totalCheckpoints checkpoints',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Points
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        TweenAnimationBuilder<int>(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          tween: IntTween(
                            begin: 0,
                            end: team.totalPoints,
                          ),
                          builder: (context, value, child) {
                            return Text(
                              '$value',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Text(
                      'points',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Progress bar
            const SizedBox(height: 12),
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  width: MediaQuery.of(context).size.width * 0.85 * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCurrentTeam
                          ? [const Color(0xFF00D9FF), const Color(0xFF8B5CF6)]
                          : [Colors.green, Colors.greenAccent],
                    ),
                    boxShadow: progress >= 1.0
                        ? [
                            BoxShadow(
                              color: (isCurrentTeam
                                      ? const Color(0xFF00D9FF)
                                      : Colors.green)
                                  .withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
