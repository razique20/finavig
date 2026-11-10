import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// Launches the AI Budget Planner page. Offered as a bottom sheet so the
/// Money hero button works without yanking the user into a full-screen push
/// unannounced; the planner itself carries the quota UI.
Future<void> showAiBudgetPlanSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final fade = FinavigTransition.of(ctx);
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: fade.color(
                      const Color(0xFFE2E5EC),
                      Colors.white.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FinavigColors.lilac.withOpacity(isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: FinavigColors.lilac,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI Budget Planner',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Tell Finavig what you want to buy or save for and Groq AI builds a '
                'month-by-month plan from your real budgets, envelopes and '
                'spending history.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/ai-budget-plan');
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Open AI Budget Planner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fade.color(
                      FinavigColors.ink,
                      FinavigColors.accentBright,
                    ),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FinavigRadius.button),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
