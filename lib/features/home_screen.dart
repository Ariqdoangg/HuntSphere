import 'package:flutter/material.dart';
import 'package:huntsphere/core/theme/app_theme.dart';
import 'package:huntsphere/features/facilitator/screens/facilitator_auth_screen.dart';
import 'package:huntsphere/features/participant/screens/participant_join_screen.dart';

const double _navbarHeight = 72.0;
const double _sectionPaddingV = 96.0;
const double _contentMaxWidth = 1120.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 40;
    if (scrolled != _isScrolled) setState(() => _isScrolled = scrolled);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundMedium,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;
          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    const SizedBox(height: _navbarHeight),
                    _buildHero(context, isDesktop),
                    _buildFeatures(isDesktop),
                    _buildHowItWorks(isDesktop),
                    _buildStatsBanner(isDesktop),
                    _buildFooter(),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildNavbar(context, isDesktop),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── NAVBAR ───────────────────────────────────────────────────────────────

  Widget _buildNavbar(BuildContext context, bool isDesktop) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _navbarHeight,
      decoration: BoxDecoration(
        color: _isScrolled
            ? AppTheme.backgroundDark.withValues(alpha: 0.97)
            : Colors.transparent,
        border: _isScrolled
            ? Border(
                bottom: BorderSide(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                ),
              )
            : null,
        boxShadow: _isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Logo + name
                _buildLogoMark(size: 36),
                const SizedBox(width: 12),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.accentGradient.createShader(bounds),
                  child: const Text(
                    'HuntSphere',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (isDesktop) ...[
                  _buildNavLink('Features', onTap: () {}),
                  const SizedBox(width: 32),
                  _buildNavLink('How It Works', onTap: () {}),
                  const SizedBox(width: 32),
                ],
                // Facilitator Login button
                _buildOutlinedNavButton(
                  label: isDesktop ? 'Facilitator Login' : 'Login',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FacilitatorAuthScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavLink(String label, {required VoidCallback onTap}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.textSecondary,
        padding: EdgeInsets.zero,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildOutlinedNavButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryBlue,
        side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  // ─── HERO ─────────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height - _navbarHeight,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D1B2A),
            Color(0xFF1B263B),
            Color(0xFF0D1B2A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Decorative glow orbs
          Positioned(
            top: -100,
            right: -80,
            child: _buildGlowOrb(
              AppTheme.primaryBlue.withValues(alpha: 0.12),
              320,
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _buildGlowOrb(
              AppTheme.primaryPink.withValues(alpha: 0.08),
              260,
            ),
          ),
          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 20,
                  vertical: _sectionPaddingV,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppTheme.primaryBlue,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'GPS-Powered Team Activities',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Headline
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppTheme.accentGradient.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        'Run Smarter\nTreasure Hunts',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 68 : 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Subtext
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        'GPS-powered team activity platform for educators and facilitators. '
                        'Create, run, and track treasure hunts in real time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 15,
                          color: AppTheme.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // CTA buttons
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildPrimaryButton(
                          label: 'Get Started as Facilitator',
                          icon: Icons.admin_panel_settings_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FacilitatorAuthScreen(),
                            ),
                          ),
                        ),
                        _buildSecondaryButton(
                          label: 'Join Activity',
                          icon: Icons.group_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ParticipantJoinScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  // ─── FEATURES ─────────────────────────────────────────────────────────────

  Widget _buildFeatures(bool isDesktop) {
    final cards = [
      _FeatureData(
        icon: Icons.location_on_outlined,
        color: AppTheme.primaryBlue,
        title: 'GPS Tracking',
        description: 'Real-time location monitoring for all teams on an interactive map.',
      ),
      _FeatureData(
        icon: Icons.leaderboard_outlined,
        color: AppTheme.primaryPurple,
        title: 'Live Leaderboard',
        description: 'Instant team rankings updated as checkpoints are completed.',
      ),
      _FeatureData(
        icon: Icons.flash_on_outlined,
        color: AppTheme.primaryPink,
        title: 'Easy Setup',
        description: 'Create and launch a full activity in minutes — no training needed.',
      ),
    ];

    return _buildSection(
      color: AppTheme.backgroundDark,
      child: Column(
        children: [
          _buildSectionHeader(
            badge: 'FEATURES',
            title: 'Everything you need\nto run great activities',
            isDesktop: isDesktop,
          ),
          const SizedBox(height: 56),
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cards
                      .map((d) => Expanded(child: _buildFeatureCard(d)))
                      .toList()
                      .expand((w) => [w, const SizedBox(width: 24)])
                      .toList()
                    ..removeLast(),
                )
              : Column(
                  children: cards
                      .map((d) => _buildFeatureCard(d))
                      .toList()
                      .expand((w) => [w, const SizedBox(height: 16)])
                      .toList()
                    ..removeLast(),
                ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureData data) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.color.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 26),
          ),
          const SizedBox(height: 20),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── HOW IT WORKS ─────────────────────────────────────────────────────────

  Widget _buildHowItWorks(bool isDesktop) {
    final steps = [
      _StepData(1, 'Create Activity', 'Set up checkpoints, tasks, and invite code in your dashboard.'),
      _StepData(2, 'Teams Join via Code', 'Participants enter the activity code to join and form teams.'),
      _StepData(3, 'Hunt Begins', 'Teams race to complete GPS checkpoints and climb the leaderboard.'),
    ];

    return _buildSection(
      color: AppTheme.backgroundMedium,
      child: Column(
        children: [
          _buildSectionHeader(
            badge: 'HOW IT WORKS',
            title: 'Up and running\nin three steps',
            isDesktop: isDesktop,
          ),
          const SizedBox(height: 56),
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: steps
                      .map((s) => Expanded(child: _buildStepCard(s, isDesktop)))
                      .toList()
                      .expand((w) => [w, _buildStepConnector()])
                      .toList()
                    ..removeLast(),
                )
              : Column(
                  children: steps
                      .map((s) => _buildStepCard(s, isDesktop))
                      .toList()
                      .expand((w) => [w, const SizedBox(height: 16)])
                      .toList()
                    ..removeLast(),
                ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Icon(
        Icons.arrow_forward,
        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
        size: 24,
      ),
    );
  }

  Widget _buildStepCard(_StepData data, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '${data.step}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATS BANNER ─────────────────────────────────────────────────────────

  Widget _buildStatsBanner(bool isDesktop) {
    final stats = [
      _StatData('30+', 'Users Tested'),
      _StatData('89%', 'GPS Accuracy'),
      _StatData('4.6/5', 'Satisfaction'),
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryBlue, AppTheme.primaryPurple],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: isDesktop ? 64 : 48,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: stats.map((s) => _buildStatItem(s, isDesktop)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(_StatData data, bool isDesktop) {
    return Column(
      children: [
        Text(
          data.value,
          style: TextStyle(
            fontSize: isDesktop ? 44 : 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.label,
          style: TextStyle(
            fontSize: isDesktop ? 15 : 12,
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── FOOTER ───────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: AppTheme.backgroundDark,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogoMark(size: 28),
              const SizedBox(width: 10),
              const Text(
                'HuntSphere',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '© 2025 HuntSphere · GPS Team Building Platform',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED HELPERS ───────────────────────────────────────────────────────

  Widget _buildSection({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      color: color,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: _sectionPaddingV,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String badge,
    required String title,
    required bool isDesktop,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppTheme.primaryPurple.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryPurple,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 40 : 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoMark({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Text(
        'H',
        style: TextStyle(
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryBlue, AppTheme.primaryPurple],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.primaryBlue, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DATA CLASSES ─────────────────────────────────────────────────────────────

class _FeatureData {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _FeatureData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _StepData {
  final int step;
  final String title;
  final String description;
  const _StepData(this.step, this.title, this.description);
}

class _StatData {
  final String value;
  final String label;
  const _StatData(this.value, this.label);
}
