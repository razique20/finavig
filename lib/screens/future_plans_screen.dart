import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Screen showing finavig's future plans and roadmap in a pictorial storytelling mode.
/// Users can navigate here from the Profile settings "What's coming in the future" section.
/// This screen excites users with visual roadmap storytelling and fintech transformation themes.
class FuturePlansScreen extends StatelessWidget {
  const FuturePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('What\'s Coming in the Future'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? FinavigColors.obsidian : FinavigColors.safe,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Background gradient with fintech vibe
          _buildBackgroundGradient(isDark),
          // Foreach content overlay
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title section
                _buildTitleSection(theme),
                const SizedBox(height: 8),
                _buildTagline(theme),
                const SizedBox(height: 32),

                // Storytelling section - the "Why"
                _buildStorySection(theme),
                const SizedBox(height: 32),

                // Roadmap visual - pictorial representation
                _buildRoadmapVisual(theme, isDark),
                const SizedBox(height: 32),

                // Coming soon cards
                _buildFeatureCards(theme),
                const SizedBox(height: 32),

                // Call to action
                _buildCTASection(theme),
                const Spacer(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the gradient background with fintech transformation theme
  Widget _buildBackgroundGradient(bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  FinavigColors.obsidian,
                  FinavigColors.charcoal,
                ]
              : [
                  FinavigColors.safe,
                  FinavigColors.safeBgLight,
                ],
        ),
      ),
    );
  }

  /// Builds the title section with fintech transformation wording
  Widget _buildTitleSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finavig Roadmap',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your fintech transformation journey',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  /// Builds the tagline/description
  Widget _buildTagline(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        'We are building the future of personal finance, one innovative feature at a time.',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the storytelling section explaining the vision
  Widget _buildStorySection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon/illustration container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FinavigColors.indigoTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              size: 40,
              color: FinavigColors.indigo,
            ),
          ),
          const SizedBox(width: 20),
          // Story text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Finance, Elevated',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: FinavigColors.indigo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We believe managing your money should be intuitive, intelligent, and inspiring. Every feature we build is designed to give you more clarity, more control, and more peace of mind.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the pictorial roadmap visualization
  Widget _buildRoadmapVisual(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Roadmap header
          Text(
            'Our Roadmap',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: FinavigColors.indigo,
            ),
          ),
          const SizedBox(height: 16),

          // Pictorial roadmap items - using visual indicators
          _RoadmapItem(
            title: 'AI Budget Plan',
            description:
                'Smart budget recommendations with AI',
            icon: Icons.auto_awesome_outlined,
            isDark: isDark,
            theme: theme,
            progress: 0.8,
          ),
          const SizedBox(height: 12),
          _RoadmapItem(
            title: 'Enhanced Analytics',
            description:
                'Deeper financial insights and trends',
            icon: Icons.stacked_line_chart_outlined,
            isDark: isDark,
            theme: theme,
            progress: 0.6,
          ),
          const SizedBox(height: 12),
          _RoadmapItem(
            title: 'Custom Categories',
            description:
                'Personalize your category organization',
            icon: Icons.settings_outlined,
            isDark: isDark,
            theme: theme,
            progress: 0.4,
          ),
          const SizedBox(height: 12),
          _RoadmapItem(
            title: 'Smart Reminders',
            description:
                'Proactive payment and bill reminders',
            icon: Icons.notifications_outlined,
            isDark: isDark,
            theme: theme,
            progress: 0.2,
          ),
        ],
      ),
    );
  }

  /// Builds feature highlight cards
  Widget _buildFeatureCards(ThemeData theme) {
    return const Text(
      'Coming Soon',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: FinavigColors.indigo,
      ),
    );
  }

  /// Builds the CTA section
  Widget _buildCTASection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'Stay tuned for more exciting updates!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// Internal widget for roadmap item with pictorial progress indicator
class _RoadmapItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isDark;
  final ThemeData theme;
  final double progress;

  const _RoadmapItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.isDark,
    required this.theme,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = FinavigColors.indigo;

    return Row(
      children: [
        // Circular progress indicator visual
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: t.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Progress bar indicator
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 4,
        ),
      ],
    );
  }
}