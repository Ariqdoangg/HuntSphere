import 'package:flutter/material.dart';
import 'package:huntsphere/core/theme/app_theme.dart';

/// A premium branded showcase screen designed for portfolio screenshots.
///
/// This screen features a full-screen gradient background with the HuntSphere logo,
/// app name, tagline, and key features. It's designed to create a stunning first
/// impression for HR/portfolio presentations.
///
/// Usage: Navigate to this screen before taking the hero screenshot for your portfolio.
class BrandShowcaseScreen extends StatelessWidget {
  const BrandShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryPurple,
              AppTheme.primaryPink,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large animated logo with glow
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1200),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: const EliteLogo(size: 150, showGlow: true),
                  );
                },
              ),

              const SizedBox(height: 40),

              // App name with gradient
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Colors.white70],
                ).createShader(bounds),
                child: const Text(
                  'HuntSphere',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tagline
              const Text(
                'GPS Treasure Hunt Platform',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 48),

              // Feature highlights
              _buildFeatureChip('🗺️ Real-time GPS Tracking'),
              const SizedBox(height: 12),
              _buildFeatureChip('👥 Team Competition'),
              const SizedBox(height: 12),
              _buildFeatureChip('✨ Elite UI Experience'),
              const SizedBox(height: 12),
              _buildFeatureChip('📊 Live Leaderboard'),

              const SizedBox(height: 60),

              // Subtle call-to-action for navigation
              Opacity(
                opacity: 0.6,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Back to App',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a feature chip with glassmorphism effect
  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
