import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Screen showing finavig's future plans and roadmap.
/// Users can navigate here from the Profile settings "What's coming in the future" section.
class FuturePlansScreen extends StatelessWidget {
  const FuturePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('What\'s Coming in the Future'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finavig Roadmap',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We are constantly working on new features to help you manage your finances better.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            const Text(
              'Roadmap items:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildRoadmapItem(context, 
              icon: Icons.auto_awesome_outlined,
              title: 'AI Budget Plan',
              description: 'Smart budget recommendations with AI',
            ),
            _buildRoadmapItem(context, 
              icon: Icons.stacked_line_chart_outlined,
              title: 'Enhanced Analytics',
              description: 'Deeper financial insights and trends',
            ),
            _buildRoadmapItem(context, 
              icon: Icons.settings_outlined,
              title: 'Custom Categories',
              description: 'Personalize your category organization',
            ),
            _buildRoadmapItem(context, 
              icon: Icons.notifications_outlined,
              title: 'Smart Reminders',
              description: 'Proactive payment and bill reminders',
            ),
            const Spacer(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapItem(BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}