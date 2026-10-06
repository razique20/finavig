import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/credit.dart';
import '../../models/finance.dart';
import '../../theme/app_theme.dart';
import 'money_sections.dart';

/// The Money tab's credit section: obligations the user borrowed
/// from or lent to someone — deadline tracking with preserved
/// extension history, overdue highlighting and WhatsApp follow-ups.
class CreditSection extends StatelessWidget {
  final List<CreditEntry> credits;
  final VoidCallback onAdd;
  final void Function(CreditEntry entry) onEdit;
  final void Function(CreditEntry entry) onDelete;
  final void Function(CreditEntry entry) onExtend;

  /// Collapse state for the Money tab, where every section can be
  /// minimized to its header. Optional so [CreditScreen] keeps
  /// using this widget as a plain, always-expanded section.
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const CreditSection({
    super.key,
    required this.credits,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onExtend,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    final header = SectionHeader(
      icon: Icons.handshake_rounded,
      title: 'Credit',
      actionLabel: 'Add',
      onAction: onAdd,
      collapsed: collapsed,
      onToggle: onToggleSection,
    );

    if (credits.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          CollapsibleSectionBody(
            collapsed: collapsed,
            children: const [
              HintCard(
                'Track money you borrowed from — or lent to — someone. '
                'Deadlines, extensions and WhatsApp follow-ups in one place.',
              ),
            ],
          ),
        ],
      );
    }

    final totals = CreditMath.totals(credits);
    final sorted = CreditMath.sortedForDisplay(credits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        CollapsibleSectionBody(
          collapsed: collapsed,
          children: [
            _TotalsRow(totals: totals),
            const SizedBox(height: 12),
            for (final entry in sorted) ...[
              _CreditCard(
                entry: entry,
                onEdit: () => onEdit(entry),
                onDelete: () => onDelete(entry),
                onExtend: () => onExtend(entry),
                onWhatsApp: () => _showFollowUpSheet(context, entry),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ],
    );
  }

  /// Template chooser → wa.me deep link with the chosen template
  /// pre-filled. Both templates are shown verbatim so the user
  /// knows exactly what will be sent.
  Future<void> _showFollowUpSheet(
    BuildContext context,
    CreditEntry entry,
  ) async {
    final friendly = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WhatsAppTemplateSheet(entry: entry),
    );
    if (friendly == null) return;

    final uri = CreditMath.followUpLink(entry, friendly: friendly);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }
}

/// Borrowed / lent / net totals strip.
class _TotalsRow extends StatelessWidget {
  final ({double borrowed, double lent, double net}) totals;

  const _TotalsRow({required this.totals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TintedCardBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _Total(
              label: 'I owe',
              value: totals.borrowed,
              color: Colors.red,
            ),
          ),
          Expanded(
            child: _Total(
              label: 'Owed to me',
              value: totals.lent,
              color: Colors.green,
            ),
          ),
          VerticalDivider(width: 24, thickness: 1, color: theme.dividerColor),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net position',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    MoneyFormat.aed(totals.net),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: totals.net < 0
                          ? Colors.red
                          : theme.colorScheme.onSurface,
                    ),
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

class _Total extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _Total({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            MoneyFormat.aed(value),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: value == 0 ? theme.colorScheme.onSurface : color,
            ),
          ),
        ),
      ],
    );
  }
}

/// One credit obligation card.
class _CreditCard extends StatelessWidget {
  final CreditEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExtend;
  final VoidCallback onWhatsApp;

  const _CreditCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onExtend,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borrowed = entry.direction == CreditDirection.borrowed;
    final flowColor = borrowed ? Colors.red : Colors.green;
    final overdue = CreditMath.isOverdue(entry);
    final hasPhone =
        (entry.counterpartyPhone?.replaceAll(RegExp(r'\D'), '') ?? '')
            .isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        // Overdue entries get a soft red outline so they stand out
        // even in a long list.
        border: overdue
            ? Border.all(color: theme.colorScheme.error.withOpacity(0.5))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: flowColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  borrowed
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 18,
                  color: flowColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.counterpartyName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${entry.direction.counterpartyRole} · '
                      '${entry.direction.flowLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  MoneyFormat.format(
                    entry.amount,
                    symbol: '${entry.currency} ',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: flowColor,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'extend':
                      onExtend();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_rounded, size: 18),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'extend',
                    child: ListTile(
                      leading: Icon(Icons.event_repeat_rounded, size: 18),
                      title: Text('Extend deadline'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DeadlineChip(entry: entry),
              if (entry.extensionCount > 0) ...[
                const SizedBox(width: 6),
                _ExtensionBadge(count: entry.extensionCount),
              ],
              const Spacer(),
              if (hasPhone)
                IconButton(
                  onPressed: onWhatsApp,
                  tooltip: 'Follow up on WhatsApp',
                  icon: const Icon(Icons.chat_rounded, size: 19),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Deadline label chip: red when overdue, amber within 3 days,
/// neutral otherwise.
class _DeadlineChip extends StatelessWidget {
  final CreditEntry entry;

  const _DeadlineChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = CreditMath.daysUntil(entry);
    final (color, icon) = days < 0
        ? (theme.colorScheme.error, Icons.alarm_rounded)
        : days <= 3
        ? (FinavigColors.warning, Icons.schedule_rounded)
        : (theme.colorScheme.outline, Icons.event_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            CreditMath.deadlineLabel(entry),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Extended ×N" badge — how many times the deadline moved.
class _ExtensionBadge extends StatelessWidget {
  final int count;

  const _ExtensionBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 12,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            count == 1 ? 'Extended once' : 'Extended ×$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Template chooser for the WhatsApp quick-action: both follow-up
/// templates shown verbatim, tap to launch wa.me with it pre-filled.
class _WhatsAppTemplateSheet extends StatelessWidget {
  final CreditEntry entry;

  const _WhatsAppTemplateSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Follow up with ${entry.counterpartyName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Opens WhatsApp with the message pre-filled — '
              'review before sending.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            _TemplateTile(
              icon: Icons.emoji_emotions_rounded,
              title: 'Friendly',
              message: CreditMath.followUpMessage(entry, friendly: true),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            _TemplateTile(
              icon: Icons.article_rounded,
              title: 'Standard',
              message: CreditMath.followUpMessage(entry, friendly: false),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
