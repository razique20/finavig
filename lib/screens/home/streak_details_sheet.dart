import 'package:flutter/material.dart';

import '../../services/streak_service.dart';
import '../../theme/app_theme.dart';

/// Shows the detailed streak bottom sheet with current streak, longest streak,
/// weekly activity calendar, and helpful tips.
Future<void> showStreakDetailsSheet(BuildContext context) {
  final theme = Theme.of(context);
  final fade = FinavigTransition.of(context);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return ListenableBuilder(
        listenable: StreakService.instance,
        builder: (context, _) {
          final current = StreakService.instance.currentStreak;
          final longest = StreakService.instance.longestStreak;
          final weekDays = StreakService.instance.weekActivity();
          final activeLast30 = StreakService.instance.activeDaysInPeriod(30);

          final now = DateTime.now();
          final monday = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1));
          final todayIdx = now.weekday - 1;

          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: fade.color(
                          Colors.black12,
                          Colors.white24,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FinavigColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activity Streak',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Track daily habits & financial health',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: fade.color(
                                  FinavigColors.textMutedLight,
                                  FinavigColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Streak Hero Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          fade.color(
                            const Color(0xFFF7F8FA),
                            FinavigColors.slate,
                          ),
                          fade.color(
                            const Color(0xFFEDEDF2),
                            FinavigColors.obsidian,
                          ),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: fade.color(
                          const Color(0xFFE2E4EB),
                          Colors.white10,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current > 0 ? '$current' : '0',
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  color: FinavigColors.accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                current == 1
                                    ? 'DAY STREAK ACTIVE'
                                    : 'DAYS STREAK ACTIVE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: fade.color(
                                    FinavigColors.textPrimaryLight,
                                    FinavigColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: fade.color(
                              Colors.white,
                              FinavigColors.slateLight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 16,
                                    color: Color(0xFFFFB300),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Best $longest d',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: fade.color(
                                        FinavigColors.textPrimaryLight,
                                        FinavigColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$activeLast30 active in 30d',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: fade.color(
                                    FinavigColors.textMutedLight,
                                    FinavigColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'THIS WEEK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: fade.color(
                        FinavigColors.textMutedLight,
                        FinavigColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Weekly Calendar Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final dayDate = monday.add(Duration(days: i));
                      final isToday = i == todayIdx;
                      final isFuture = i > todayIdx;
                      final isActive = weekDays[i];

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isToday
                                ? FinavigColors.accent.withValues(alpha: 0.12)
                                : (isActive
                                    ? fade.color(
                                        const Color(0xFFEAEBED),
                                        FinavigColors.slate,
                                      )
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isToday
                                  ? FinavigColors.accent
                                  : (isActive
                                      ? Colors.transparent
                                      : fade.color(
                                          const Color(0xFFE2E4EB),
                                          Colors.white12,
                                        )),
                              width: isToday ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dayNames[i],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isToday
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isToday
                                      ? FinavigColors.accent
                                      : fade.color(
                                          FinavigColors.textSecondaryLight,
                                          FinavigColors.textSecondary,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dayDate.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isToday
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: fade.color(
                                    FinavigColors.textPrimaryLight,
                                    FinavigColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive
                                      ? FinavigColors.accent
                                      : (isFuture
                                          ? Colors.transparent
                                          : fade.color(
                                              Colors.black12,
                                              Colors.white10,
                                            )),
                                ),
                                child: isActive
                                    ? const Icon(
                                        Icons.check,
                                        size: 11,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'HOW IT WORKS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: fade.color(
                        FinavigColors.textMutedLight,
                        FinavigColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _TipRow(
                    icon: Icons.login_rounded,
                    title: 'Daily App Check-In',
                    subtitle: 'Opening Finavig automatically counts toward your streak.',
                  ),
                  const SizedBox(height: 8),
                  _TipRow(
                    icon: Icons.receipt_long_rounded,
                    title: 'Log Expenses & Payments',
                    subtitle: 'Recording transactions or scanning bills marks that date as active.',
                  ),
                  const SizedBox(height: 8),
                  _TipRow(
                    icon: Icons.description_outlined,
                    title: 'Manage Documents',
                    subtitle: 'Adding or updating policies, IDs, and subscriptions counts as activity.',
                  ),

                  const SizedBox(height: 22),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FinavigColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Got It',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
    },
  );
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TipRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: fade.color(
              const Color(0xFFF0F1F5),
              FinavigColors.slate,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: fade.color(
              FinavigColors.textPrimaryLight,
              FinavigColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fade.color(
                    FinavigColors.textPrimaryLight,
                    FinavigColors.textPrimary,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: fade.color(
                    FinavigColors.textMutedLight,
                    FinavigColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
