import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/finance.dart';
import 'theme/app_theme.dart';
import 'models/expiry_item.dart';
import 'services/alert_preferences_service.dart';
import 'services/budget_alert_service.dart';
import 'services/document_scanner_service.dart';
import 'services/finance_service.dart';
import 'services/perf_tracing_service.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/document_scan_screen.dart';
import 'screens/document_detail_screen.dart';
import 'screens/expiry_list_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/money_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/envelopes_screen.dart';
import 'screens/records_screen.dart';
import 'screens/credits_screen.dart';
import 'screens/cash_flow_forecast_screen.dart';
import 'screens/global_search_screen.dart';
import 'screens/ai_summary_screen.dart';
import 'screens/ai_budget_plan_screen.dart';
import 'screens/alerts_reminders_screen.dart';
import 'services/auth_service.dart';
import 'services/tab_scroll_registry.dart';
import 'widgets/dialogs/quick_action_sheet.dart';
import 'widgets/indicators/offline_banner.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeShellKey = GlobalKey<NavigatorState>();
final _documentsShellKey = GlobalKey<NavigatorState>();
final _moneyShellKey = GlobalKey<NavigatorState>();
final _profileShellKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  // Auth gate: when Supabase is configured, every route except /login and /
  // requires a session. In local-only mode (no credentials) the gate is off.
  redirect: (context, state) {
    final auth = AuthService.instance;
    if (!auth.isAvailable) return null;

    final signedIn = auth.isSignedIn;
    final path = state.uri.path;
    final isAuthRoute = path == '/login' || path == '/welcome';

    if (!signedIn && !isAuthRoute && path != '/') return '/login';
    if (signedIn && isAuthRoute) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OnboardingScreen(),
    ),
    // Full-screen flows above the shell.
    GoRoute(
      path: '/scan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extraItem = state.extra as ExpiryItem?;
        return DocumentScanScreen(initialItem: extraItem);
      },
    ),
    GoRoute(
      path: '/document/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        PerfTracingService.markFlow(PerfTracingService.flowDocumentOpen);
        return DocumentDetailScreen(documentId: id);
      },
    ),
    GoRoute(
      path: '/document/:id/edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extraItem = state.extra as ExpiryItem?;
        return DocumentScanScreen(documentId: id, initialItem: extraItem);
      },
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GlobalSearchScreen(),
    ),
    GoRoute(
      path: '/expiry-list',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExpiryListScreen(),
    ),
    GoRoute(
      path: '/cash-flow-forecast',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CashFlowForecastScreen(),
    ),
    // Focused pages behind the Home categories grid (Money sub-features).
    GoRoute(
      path: '/budgets',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BudgetsScreen(),
    ),
    GoRoute(
      path: '/envelopes',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EnvelopesScreen(),
    ),
    GoRoute(
      path: '/records',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RecordsScreen(),
    ),
    GoRoute(
      path: '/credits',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CreditsScreen(),
    ),
    GoRoute(
      path: '/ai-summary',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AiSummaryScreen(),
    ),
    GoRoute(
      path: '/ai-budget-plan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AiBudgetPlanScreen(),
    ),
    GoRoute(
      path: '/alerts-reminders',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AlertsRemindersScreen(),
    ),
    // 4-tab bottom-nav shell:
    //   Home      — cross-tier dashboard (documents + money summary)
    //   Money     — Tier 2: budgets, envelopes, transactions
    //   Documents — Tier 1: full expiry tracking
    //   Profile   — settings, collections, account
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => _AppShell(
        navigationShell: navigationShell,
      ),
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeShellKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _moneyShellKey,
          routes: [
            GoRoute(
              path: '/money',
              builder: (context, state) => const MoneyScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _documentsShellKey,
          routes: [
            GoRoute(
              path: '/documents',
              builder: (context, state) => const DocumentsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _profileShellKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.uri}')),
  ),
);/// Bottom navigation shell with the four main tabs.
///
/// Floating dark pill design: icon-only destinations with a filled circular
/// indicator for the active tab, plus a center "universal quick action" (+)
/// button that opens the 1-tap menu for every core creation flow.
///
/// Destinations carry live context:
/// * Documents — red badge when any tracked document needs action (≤30 days).
/// * Money — amber dot when a budget is ≥80% used, red when ≥100%.
///
/// Global search stays reachable from the Home categories grid, the
/// Documents hero, and the Money/Settings quick actions.
class _AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const _AppShell({required this.navigationShell});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  List<ExpiryItem> _items = [];
  BudgetStatusResult? _budgetStatus;

  @override
  void initState() {
    super.initState();
    _loadItems();
    DocumentScannerService.instance.addListener(_onItemsChanged);
    FinanceService.instance.addListener(_onFinanceChanged);
    _refreshBudgetStatus();
  }

  @override
  void dispose() {
    DocumentScannerService.instance.removeListener(_onItemsChanged);
    FinanceService.instance.removeListener(_onFinanceChanged);
    super.dispose();
  }

  void _onFinanceChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshBudgetStatus();
    });
  }

  void _refreshBudgetStatus() {
    // Badge mirrors the alerts: hidden entirely when the user disabled
    // budget alerts in Profile.
    if (!AlertPreferencesService.instance.budgetAlertsEnabled) {
      setState(() => _budgetStatus = null);
      return;
    }
    setState(() => _budgetStatus = BudgetAlertService.instance.worstStatus);
  }

  Future<void> _loadItems() async {
    final items = await DocumentScannerService.instance.getAllItems();
    if (mounted) setState(() => _items = items);
  }

  void _onItemsChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingDocs = _items.where((i) => i.daysRemaining <= 30).length;
    // Resolve every light/dark pair through the theme transition factor so the
    // whole dock cross-fades with the theme animation. Branching on `isDark`
    // made the pill, its shadow and its icons snap in one frame halfway
    // through the switch — a visible blink.
    final fade = FinavigTransition.of(context);

    return Scaffold(
      // Slim offline notice above everything — explains queued sync instead
      // of letting silence read as "broken".
      backgroundColor: fade.color(FinavigColors.ink, FinavigColors.obsidian),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.navigationShell),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            // Soft white pill on light mode, deep surface on dark — modern
            // floating dock with a diffuse shadow instead of a hard black bar.
            color: fade.color(
              Colors.white,
              FinavigColors.slate.withValues(alpha: 0.92),
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: fade.color(
                  FinavigShadows.raised.first.color,
                  Colors.black.withValues(alpha: 0.4),
                ),
                blurRadius: fade.value(FinavigShadows.raised.first.blurRadius, 24),
                offset: Offset(0, fade.value(FinavigShadows.raised.first.offset.dy, 8)),
              ),
            ],
          ),
          // Fixed height: the Center inside each item would otherwise
          // expand into the loose height constraints of the nav slot.
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _NavPillItem(
                  icon: widget.navigationShell.currentIndex == 0
                      ? Icons.home_rounded
                      : Icons.home_outlined,
                  active: widget.navigationShell.currentIndex == 0,
                  tooltip: 'Home',
                  onTap: () => _goBranch(0),
                ),
                _NavPillItem(
                  icon: widget.navigationShell.currentIndex == 1
                      ? Icons.account_balance_wallet_rounded
                      : Icons.account_balance_wallet_outlined,
                  active: widget.navigationShell.currentIndex == 1,
                  tooltip: 'Money',
                  showDot: _budgetStatus != null,
                  dotColor:
                      _budgetStatus?.status == BudgetAlertLevel.exceeded
                          ? FinavigColors.danger
                          : FinavigColors.warning,
                  onTap: () => _goBranch(1),
                ),
                // Universal quick action (+): scan a document, log money,
                // voice AI log, or create an envelope from any tab.
                // Long-press skips the menu and opens Ask Finavig AI.
                _QuickActionButton(
                  onTap: () => showQuickActionSheet(context),
                  onLongPress: () => showAskFinavigFlow(context),
                ),
                _NavPillItem(
                  icon: widget.navigationShell.currentIndex == 2
                      ? Icons.description_rounded
                      : Icons.description_outlined,
                  active: widget.navigationShell.currentIndex == 2,
                  tooltip: 'Documents',
                  showDot: pendingDocs > 0,
                  dotColor: FinavigColors.danger,
                  onTap: () => _goBranch(2),
                ),
                _NavPillItem(
                  icon: widget.navigationShell.currentIndex == 3
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  active: widget.navigationShell.currentIndex == 3,
                  tooltip: 'Profile',
                  onTap: () => _goBranch(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    // Every tab tap lands at the top of that tab's screen. Tapping the
    // already-active tab also resets its scroll (standard mobile pattern).
    TabScrollRegistry.scrollToTop(index);
    PerfTracingService.trace(PerfTracingService.flowTabSwitch, () {
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
    });
  }
}

/// Center "universal quick action" (+) button inside the nav pill: a flat
/// violet orb that opens the quick action menu from any tab.
class _QuickActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickActionButton({
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Tooltip(
          message: 'Quick actions\nHold for Ask Finavig AI',
          waitDuration: const Duration(milliseconds: 600),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(19),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [FinavigColors.violet, FinavigColors.violetDark],
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One icon-only destination inside the floating nav pill. The active tab
/// gets a filled circular backdrop; status dots mirror the shell badges.
class _NavPillItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;
  final Color? dotColor;

  const _NavPillItem({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    // Dock colours resolve through the theme transition factor so the pill,
    // the active-tab backdrop and every glyph cross-fade with the theme
    // animation instead of snapping at its halfway point.
    final fade = FinavigTransition.of(context);
    return Expanded(
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? fade.color(
                              FinavigColors.ink,
                              Colors.white.withValues(alpha: 0.14),
                            )
                          : Colors.transparent,
                    ),
                    child: Icon(
                      icon,
                      size: 21,
                      color: active
                          ? Colors.white
                          // White in dark mode — dimmed just enough that the
                          // active tab still reads against it.
                          : fade.color(
                              FinavigColors.textMutedLight,
                              Colors.white.withValues(alpha: 0.65),
                            ),
                    ),
                  ),
                  if (showDot)
                    Positioned(
                      right: 3,
                      top: 2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: dotColor ?? FinavigColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: fade.color(
                              Colors.white,
                              FinavigColors.slate,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

