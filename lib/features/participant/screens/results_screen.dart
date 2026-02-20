import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import '../../facilitator/screens/facilitator_dashboard.dart';
import '../../shared/screens/photo_gallery_screen.dart';

class ResultsScreen extends StatefulWidget {
  final String activityId;
  final bool isFacilitator;

  const ResultsScreen({
    super.key,
    required this.activityId,
    this.isFacilitator = false,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> teams = [];
  Map<String, dynamic>? activity;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _loadResults();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    try {
      final activityResponse = await Supabase.instance.client
          .from('activities')
          .select()
          .eq('id', widget.activityId)
          .single();

      final teamsResponse = await Supabase.instance.client
          .from('teams')
          .select()
          .eq('activity_id', widget.activityId)
          .order('total_points', ascending: false)
          .order('finished_at', ascending: true, nullsFirst: false);

      if (mounted) {
        setState(() {
          activity = activityResponse;
          teams = List<Map<String, dynamic>>.from(teamsResponse);
          isLoading = false;
        });
        _animationController.forward();
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('Error loading results: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: AppTheme.spacingL),
                      if (teams.isNotEmpty) ...[
                        _buildWinnerCard(teams.first),
                        const SizedBox(height: AppTheme.spacingL),
                        _buildAllTeamsRanking(),
                      ] else
                        _buildNoTeamsMessage(),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildActionButtons(),
                      const SizedBox(height: AppTheme.spacingM),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.warning.withValues(alpha: 0.2),
                  AppTheme.primaryPurple.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Text(
              '🎉',
              style: TextStyle(fontSize: 48),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        FadeTransition(
          opacity: _fadeAnimation,
          child: const GradientText(
            text: 'GAME OVER!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
            gradient: LinearGradient(
              colors: [AppTheme.accent, AppTheme.primaryPurple],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            activity?['name'] ?? 'Activity',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildNoTeamsMessage() {
    return EliteCard(
      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'No teams participated',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerCard(Map<String, dynamic> winner) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: EliteCard(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.warning.withValues(alpha: 0.25),
            AppTheme.warning.withValues(alpha: 0.1),
            AppTheme.backgroundCard,
          ],
        ),
        showBorder: true,
        child: Column(
          children: [
            const Text('👑', style: TextStyle(fontSize: 40)),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              ),
              child: Text(
                'WINNER',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  winner['emoji'] ?? '🔥',
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  winner['team_name'] ?? 'Team',
                  style: AppTheme.headingMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.warning.withValues(alpha: 0.3),
                    AppTheme.warning.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppTheme.warning, size: 20),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    '${winner['total_points'] ?? 0} points',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.bold,
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

  Widget _buildAllTeamsRanking() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'FINAL RANKINGS',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          ...teams.asMap().entries.map((entry) {
            final index = entry.key;
            final team = entry.value;
            return _buildRankingItem(team, index + 1);
          }),
        ],
      ),
    );
  }

  Widget _buildRankingItem(Map<String, dynamic> team, int rank) {
    String medal;
    Color rankColor;

    switch (rank) {
      case 1:
        medal = '🥇';
        rankColor = const Color(0xFFFFD700);
        break;
      case 2:
        medal = '🥈';
        rankColor = const Color(0xFFC0C0C0);
        break;
      case 3:
        medal = '🥉';
        rankColor = const Color(0xFFCD7F32);
        break;
      default:
        medal = '';
        rankColor = AppTheme.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: rank == 1
            ? AppTheme.warning.withValues(alpha: 0.1)
            : AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: rank == 1
              ? AppTheme.warning.withValues(alpha: 0.3)
              : AppTheme.backgroundElevated,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? rankColor.withValues(alpha: 0.2)
                  : AppTheme.backgroundElevated,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Center(
              child: rank <= 3
                  ? Text(medal, style: const TextStyle(fontSize: 18))
                  : Text(
                      '$rank',
                      style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),

          // Team Info
          Expanded(
            child: Row(
              children: [
                Text(
                  team['emoji'] ?? '👥',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    team['team_name'] ?? 'Team',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: rank == 1 ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Points
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppTheme.warning.withValues(alpha: 0.2)
                  : AppTheme.backgroundElevated,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: rank == 1 ? AppTheme.warning : AppTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${team['total_points'] ?? 0}',
                  style: AppTheme.labelMedium.copyWith(
                    color: rank == 1 ? AppTheme.warning : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Photo Gallery Button
        SizedBox(
          width: double.infinity,
          child: EliteButton(
            label: 'View Photo Gallery',
            icon: Icons.photo_library_rounded,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PhotoGalleryScreen(
                    activityId: widget.activityId,
                    activityName: activity?['name'] ?? 'Activity',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        // Back Button
        SizedBox(
          width: double.infinity,
          child: EliteButton(
            label: widget.isFacilitator ? 'Back to Dashboard' : 'Back to Home',
            icon: widget.isFacilitator
                ? Icons.dashboard_rounded
                : Icons.home_rounded,
            onPressed: () {
              if (widget.isFacilitator) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const FacilitatorDashboard()),
                  (route) => false,
                );
              } else {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
        ),
      ],
    );
  }
}
