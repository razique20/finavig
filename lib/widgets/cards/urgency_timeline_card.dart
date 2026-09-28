import 'package:flutter/material.dart';

/// One step of the [UrgencyTimelineCard] — a vertical connector line over a
/// status circle, step label, and description.
class UrgencyTimelineStep extends StatelessWidget {
  final int days;
  final String label;
  final String description;
  final bool isActive;
  final bool isCompleted;
  final Color color;
  final IconData icon;

  const UrgencyTimelineStep({
    super.key,
    required this.days,
    required this.label,
    required this.description,
    required this.isActive,
    required this.isCompleted,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top connector line
        Container(
          height: 3,
          width: double.infinity,
          color: isActive
              ? color
              : isCompleted
              ? color.withOpacity(0.4)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive
                      ? color
                      : isCompleted
                      ? color.withOpacity(0.2)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted
                        ? color.withOpacity(0.4)
                        : isActive
                        ? color
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check : icon,
                  color: isCompleted
                      ? color
                      : isActive
                      ? Colors.white
                      : Colors.transparent,
                  size: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? color
                      : isCompleted
                      ? Colors.grey
                      : Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isActive ? color : Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 90·60·30·7-day renewal urgency timeline — the single shared
/// implementation of the alert ladder, extracted from
/// `document_detail_screen.dart` so Home, Documents, and the detail screen
/// render one consistent UI.
///
/// Renders the four milestone steps (Reminder → Task → Escalation →
/// WhatsApp), highlights the active one, and appends a "current step"
/// indicator when [showCurrentStep] is set.
class UrgencyTimelineCard extends StatelessWidget {
  final int daysRemaining;
  final bool showCurrentStep;

  const UrgencyTimelineCard({super.key, required this.daysRemaining})
      : showCurrentStep = false;

  /// Full variant with the current-step indicator, used by the detail screen.
  const UrgencyTimelineCard.withIndicator({
    super.key,
    required this.daysRemaining,
  }) : showCurrentStep = true;

  @override
  Widget build(BuildContext context) {
    final days = daysRemaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Urgency timeline',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // Timeline
        Row(
          children: [
            // 90 days
            Expanded(
              child: UrgencyTimelineStep(
                days: 90,
                label: 'Reminder',
                description: '90-day reminder sent',
                isActive: days <= 90 && days > 60,
                isCompleted: days > 90,
                color: Colors.indigo,
                icon: Icons.notifications_active_rounded,
              ),
            ),
            // 60 days
            Expanded(
              child: UrgencyTimelineStep(
                days: 60,
                label: 'Task assigned',
                description: 'Renewal task created',
                isActive: days <= 60 && days > 30,
                isCompleted: days > 60,
                color: Colors.amber,
                icon: Icons.assignment_turned_in_rounded,
              ),
            ),
            // 30 days
            Expanded(
              child: UrgencyTimelineStep(
                days: 30,
                label: 'Escalation',
                description: 'Stakeholder escalation',
                isActive: days <= 30 && days > 7,
                isCompleted: days > 30,
                color: Colors.orange,
                icon: Icons.priority_high_rounded,
              ),
            ),
            // 7 days
            Expanded(
              child: UrgencyTimelineStep(
                days: 7,
                label: 'Final week',
                description: 'Urgent final reminder',
                isActive: days <= 7,
                isCompleted: false,
                color: Colors.red,
                icon: Icons.whatshot_rounded,
              ),
            ),
          ],
        ),
        if (showCurrentStep) ...[
          const SizedBox(height: 12),
          _buildCurrentStepIndicator(context, _currentStep(days)),
        ],
      ],
    );
  }

  static UrgencyCurrentStep _currentStep(int days) {
    if (days > 90) {
      return UrgencyCurrentStep(
        label: 'On track',
        color: Colors.green,
        icon: Icons.check_circle_rounded,
        description: 'All renewal milestones on schedule',
        daysLeft: days,
      );
    } else if (days > 60) {
      return UrgencyCurrentStep(
        label: '90-day reminder due',
        color: Colors.indigo,
        icon: Icons.notifications_active_rounded,
        description: 'Remind the responsible person',
        daysLeft: days,
      );
    } else if (days > 30) {
      return UrgencyCurrentStep(
        label: '60-day task due',
        color: Colors.amber,
        icon: Icons.assignment_turned_in_rounded,
        description: 'Assign renewal task to team member',
        daysLeft: days,
      );
    } else if (days > 7) {
      return UrgencyCurrentStep(
        label: '30-day escalation triggered',
        color: Colors.orange,
        icon: Icons.priority_high_rounded,
        description: 'Escalating to management',
        daysLeft: days,
      );
    } else {
      return UrgencyCurrentStep(
        label: '7-day final reminder',
        color: Colors.red,
        icon: Icons.whatshot_rounded,
        description: 'Final week before expiry — act now',
        daysLeft: days,
      );
    }
  }
}

/// The currently-active ladder step, derived from days remaining.
class UrgencyCurrentStep {
  final String label;
  final Color color;
  final IconData icon;
  final String description;
  final int daysLeft;

  const UrgencyCurrentStep({
    required this.label,
    required this.color,
    required this.icon,
    required this.description,
    this.daysLeft = 0,
  });
}

Widget _buildCurrentStepIndicator(BuildContext context, UrgencyCurrentStep step) {
  final theme = Theme.of(context);
  final color = step.color;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(step.icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                step.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${step.daysLeft} days left',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}
