import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/alert_preferences_service.dart';
import '../services/document_scanner_service.dart';
import '../services/notification_service.dart';
import '../services/pending_transaction_service.dart';
import '../services/transaction_notification_listener.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_detection_card.dart';
import '../widgets/widgets.dart';

/// Full-screen settings page dedicated to managing Alert toggles and
/// Document Expiry Reminder lead times.
class AlertsRemindersScreen extends StatefulWidget {
  const AlertsRemindersScreen({super.key});

  @override
  State<AlertsRemindersScreen> createState() => _AlertsRemindersScreenState();
}

class _AlertsRemindersScreenState extends State<AlertsRemindersScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _notificationsEnabled = true;
  bool _billSpikesEnabled = true;
  bool _budgetAlertsEnabled = true;

  bool _detectionEnabled = false;
  bool _hasListenerPermission = false;
  int _pendingTxCount = 0;

  int _reminderCadence = 90;
  int _taskCadence = 60;
  int _escalationCadence = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TransactionNotificationListener.instance.addListener(_syncDetectionState);
    PendingTransactionService.instance.addListener(_syncDetectionState);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TransactionNotificationListener.instance.removeListener(_syncDetectionState);
    PendingTransactionService.instance.removeListener(_syncDetectionState);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  void _syncDetectionState() {
    if (!mounted) return;
    setState(() {
      _detectionEnabled = TransactionNotificationListener.instance.isEnabled;
      _hasListenerPermission = TransactionNotificationListener.instance.hasPermission;
      _pendingTxCount = PendingTransactionService.instance.pendingCount;
    });
  }

  Future<void> _checkPermission() async {
    final hasPerm =
        await TransactionNotificationListener.instance.checkPermission();
    if (!mounted) return;
    setState(() => _hasListenerPermission = hasPerm);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsService = AlertPreferencesService.instance;
    await alertsService.load();

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _reminderCadence = prefs.getInt('reminderCadence') ?? 90;
      _taskCadence = prefs.getInt('taskCadence') ?? 60;
      _escalationCadence = prefs.getInt('escalationCadence') ?? 30;

      _billSpikesEnabled = alertsService.billSpikesEnabled;
      _budgetAlertsEnabled = alertsService.budgetAlertsEnabled;

      _detectionEnabled = TransactionNotificationListener.instance.isEnabled;
      _hasListenerPermission =
          TransactionNotificationListener.instance.hasPermission;
      _pendingTxCount = PendingTransactionService.instance.pendingCount;
      _loading = false;
    });
  }

  Future<void> _applyReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setInt('reminderCadence', _reminderCadence);
    await prefs.setInt('taskCadence', _taskCadence);
    await prefs.setInt('escalationCadence', _escalationCadence);

    try {
      final items = await DocumentScannerService.instance.getAllItems();
      for (final item in items) {
        if (_notificationsEnabled) {
          await NotificationService.instance.scheduleEscalationLadder(
            item.id,
            item.expiresAt,
            title: item.displayName,
          );
        } else {
          await NotificationService.instance.cancelReminders(item.id);
        }
      }
    } catch (_) {
      // Scheduling may be unavailable in some environments (e.g. tests)
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fade = FinavigTransition.of(context);

    return Scaffold(
      backgroundColor: fade.color(FinavigColors.snowWhite, FinavigColors.obsidian),
      appBar: AppBar(
        title: const Text('Alerts & Reminders'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Informational banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: FinavigColors.indigo.withValues(
                            alpha: isDark ? 0.18 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: FinavigColors.indigo.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: FinavigColors.indigo.withValues(
                                  alpha: 0.2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: FinavigColors.indigo,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Configure proactive alerts for document expiries, budget caps, and unusual monthly bill spikes.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Group 1: Notification Toggles
                      _buildGroupTitle(theme, 'Alert Notifications'),
                      const SizedBox(height: 14),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildSwitchTile(
                            theme: theme,
                            icon: Icons.notifications_rounded,
                            iconColor: FinavigColors.indigo,
                            title: 'Renewal notifications',
                            subtitle: 'Remind me before documents expire',
                            value: _notificationsEnabled,
                            onChanged: (val) async {
                              setState(() => _notificationsEnabled = val);
                              await _applyReminderSettings();
                            },
                          ),
                          _buildDivider(isDark),
                          _buildSwitchTile(
                            theme: theme,
                            icon: Icons.trending_up_rounded,
                            iconColor: FinavigColors.warning,
                            title: 'Bill spike alerts',
                            subtitle:
                                'Flag bills unusually higher than average',
                            value: _billSpikesEnabled,
                            onChanged: (val) async {
                              setState(() => _billSpikesEnabled = val);
                              await AlertPreferencesService.instance
                                  .setBillSpikesEnabled(val);
                            },
                          ),
                          _buildDivider(isDark),
                          _buildSwitchTile(
                            theme: theme,
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: FinavigColors.emerald,
                            title: 'Budget alerts',
                            subtitle:
                                'Warn when spending nears a category budget',
                            value: _budgetAlertsEnabled,
                            onChanged: (val) async {
                              setState(() => _budgetAlertsEnabled = val);
                              await AlertPreferencesService.instance
                                  .setBudgetAlertsEnabled(val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Group 2: Reminder Lead Times
                      _buildGroupTitle(theme, 'Reminder Lead Times & Schedule'),
                      const SizedBox(height: 14),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildDropdownTile<int>(
                            theme: theme,
                            icon: Icons.notifications_active_rounded,
                            iconColor: Colors.indigo,
                            title: 'First reminder',
                            subtitle:
                                'Initial alert before document expiration',
                            value: _reminderCadence,
                            items: const [30, 60, 90, 120],
                            itemLabel: (v) => '$v days before expiry',
                            onChanged: (v) async {
                              if (v != null) {
                                setState(() => _reminderCadence = v);
                                await _applyReminderSettings();
                              }
                            },
                          ),
                          _buildDivider(isDark),
                          _buildDropdownTile<int>(
                            theme: theme,
                            icon: Icons.assignment_turned_in_rounded,
                            iconColor: Colors.amber.shade700,
                            title: 'Renewal task',
                            subtitle: 'Assign task & prepare renewal papers',
                            value: _taskCadence,
                            items: const [30, 45, 60, 75, 90],
                            itemLabel: (v) => '$v days before expiry',
                            onChanged: (v) async {
                              if (v != null) {
                                setState(() => _taskCadence = v);
                                await _applyReminderSettings();
                              }
                            },
                          ),
                          _buildDivider(isDark),
                          _buildDropdownTile<int>(
                            theme: theme,
                            icon: Icons.priority_high_rounded,
                            iconColor: FinavigColors.danger,
                            title: 'Escalation',
                            subtitle: 'Final escalation to stakeholders',
                            value: _escalationCadence,
                            items: const [15, 21, 30, 45],
                            itemLabel: (v) => '$v days before expiry',
                            onChanged: (v) async {
                              if (v != null) {
                                setState(() => _escalationCadence = v);
                                await _applyReminderSettings();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Group 3: Bank Transaction Detection
                      _buildGroupTitle(theme, 'Bank Transaction Detection'),
                      const SizedBox(height: 14),
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildSwitchTile(
                            theme: theme,
                            icon: Icons.receipt_long_rounded,
                            iconColor: FinavigColors.indigo,
                            title: 'Auto-detect transactions',
                            subtitle:
                                'Extract expenses & income automatically from banking notifications',
                            value: _detectionEnabled,
                            onChanged: (val) async {
                              setState(() => _detectionEnabled = val);
                              await TransactionNotificationListener.instance
                                  .setEnabled(val);
                              await _checkPermission();
                            },
                          ),
                          if (Platform.isAndroid) ...[
                            _buildDivider(isDark),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              leading: BentoIconTile(
                                icon: _hasListenerPermission
                                    ? Icons.verified_user_rounded
                                    : Icons.security_rounded,
                                color: _hasListenerPermission
                                    ? FinavigColors.emerald
                                    : Colors.amber.shade700,
                                size: 38,
                                iconSize: 18,
                                radius: 12,
                              ),
                              title: Text(
                                'Notification access',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _hasListenerPermission
                                    ? 'Access granted • Active'
                                    : 'Required by Android to read bank alerts • Tap to grant',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _hasListenerPermission
                                      ? FinavigColors.emerald
                                      : Colors.amber.shade700,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (_hasListenerPermission
                                          ? FinavigColors.emerald
                                          : Colors.amber.shade700)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _hasListenerPermission ? 'Active' : 'Grant',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _hasListenerPermission
                                        ? FinavigColors.emerald
                                        : Colors.amber.shade700,
                                  ),
                                ),
                              ),
                              onTap: () async {
                                await TransactionNotificationListener.instance
                                    .openPermissionSettings();
                              },
                            ),
                          ],
                          _buildDivider(isDark),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            leading: BentoIconTile(
                              icon: Icons.pending_actions_rounded,
                              color: Colors.amber.shade700,
                              size: 38,
                              iconSize: 18,
                              radius: 12,
                            ),
                            title: Text(
                              'Pending review queue',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _pendingTxCount > 0
                                  ? '$_pendingTxCount transactions waiting for confirmation'
                                  : 'No pending transactions',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_pendingTxCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$_pendingTxCount',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                              ],
                            ),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const PendingTransactionsList(),
                              );
                            },
                          ),
                          _buildDivider(isDark),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            leading: const BentoIconTile(
                              icon: Icons.content_paste_rounded,
                              color: FinavigColors.orange,
                              size: 38,
                              iconSize: 18,
                              radius: 12,
                            ),
                            title: Text(
                              'Paste bank SMS / alert',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Manually parse transaction text',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: theme.colorScheme.outline,
                            ),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const SmsPasteImport(),
                              );
                            },
                          ),
                          _buildDivider(isDark),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            leading: const BentoIconTile(
                              icon: Icons.science_outlined,
                              color: FinavigColors.sky,
                              size: 38,
                              iconSize: 18,
                              radius: 12,
                            ),
                            title: Text(
                              'Test auto-detection',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Simulate an incoming bank notification now',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: theme.colorScheme.outline,
                            ),
                            onTap: () => _showTestNotificationSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Material(
      color: isDark ? FinavigColors.slate.withValues(alpha: 0.5) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 52,
      endIndent: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05),
    );
  }

  Widget _buildSwitchTile({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: BentoIconTile(
        icon: icon,
        color: iconColor,
        size: 38,
        iconSize: 18,
        radius: 12,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }

  Widget _buildDropdownTile<T>({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: BentoIconTile(
        icon: icon,
        color: iconColor,
        size: 38,
        iconSize: 18,
        radius: 12,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          itemLabel(value),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ),
      onTap: () {
        final fade = FinavigTransition.of(context);
        showModalBottomSheet<T>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: fade.color(
                      const Color(0xFFE2E5EC),
                      Colors.white.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final item in items)
                  ListTile(
                    title: Text(itemLabel(item)),
                    trailing: item == value
                        ? Icon(Icons.check_circle_rounded, color: iconColor)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(item);
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTestNotificationSheet(BuildContext context) {
    final theme = Theme.of(context);
    final scenarios = [
      (
        bank: 'Emirates NBD',
        title: 'Emirates NBD',
        text:
            'Purchase of AED 245.50 with Debit Card ending 4321 at Carrefour on 06-Nov-2026. Avl Bal AED 12,450.00',
        pkg: 'com.enbd.mobilebanking',
        icon: Icons.shopping_cart_rounded,
        color: FinavigColors.indigo,
      ),
      (
        bank: 'ADCB Dining',
        title: 'ADCB',
        text:
            'Dear Customer, your Credit Card ending 9876 was used for AED 85.00 at Starbucks Dubai Mall.',
        pkg: 'com.adcb.bank',
        icon: Icons.coffee_rounded,
        color: Colors.amber.shade800,
      ),
      (
        bank: 'FAB DEWA Bill',
        title: 'FAB',
        text:
            'Your account **1234 has been debited with AED 1,200.00 for DEWA electricity payment.',
        pkg: 'com.firstabudhabibank.fab',
        icon: Icons.bolt_rounded,
        color: FinavigColors.emerald,
      ),
      (
        bank: 'WhatsApp Banking',
        title: 'Emirates NBD',
        text:
            'Transaction alert: You have paid AED 45.00 at Costa Coffee using Card ending 1234.',
        pkg: 'com.whatsapp',
        icon: Icons.chat_rounded,
        color: const Color(0xFF25D366),
      ),
      (
        bank: 'Saudi SAR (Al Rajhi)',
        title: 'Al Rajhi Bank',
        text:
            'Purchase of SAR 320.00 using mada card *7712 at Panda Hypermarket.',
        pkg: 'com.alrajhi.mobile',
        icon: Icons.storefront_rounded,
        color: Colors.teal,
      ),
    ];

    final fade = FinavigTransition.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: fade.color(
                    const Color(0xFFE2E5EC),
                    Colors.white.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Simulate Bank Notification',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select a sample alert to test the detection card overlay and de-duplication pipeline',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              for (final s in scenarios)
                ListTile(
                  leading: BentoIconTile(
                    icon: s.icon,
                    color: s.color,
                    size: 38,
                    iconSize: 18,
                    radius: 12,
                  ),
                  title: Text(
                    s.bank,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    s.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final added = await TransactionNotificationListener.instance
                        .simulateNotification(
                      text: s.text,
                      title: s.title,
                      packageName: s.pkg,
                    );
                    if (!added && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Dropped: detected as duplicate within recent 15min window!',
                          ),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
