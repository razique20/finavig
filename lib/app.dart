import 'package:flutter/material.dart';

import 'router.dart';
import 'services/auth_service.dart';
import 'services/dodo_payments_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';

class FinavigApp extends StatefulWidget {
  const FinavigApp({super.key});

  @override
  State<FinavigApp> createState() => _FinavigAppState();
}

class _FinavigAppState extends State<FinavigApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AuthService.instance.isSignedIn) {
      // When user returns from checkout browser, verify payment and refresh tier
      DodoPaymentsService.instance.verifyAndRefreshTier();
    }
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Finavig',
      debugShowCheckedModeBanner: false,
      theme: FinavigTheme.light(),
      darkTheme: FinavigTheme.dark(),
      themeMode: ThemeService.instance.mode,
      routerConfig: router,
      // Local passcode lock — overlays the lock screen above every route and
      // dialog when the app is reopened (cold start or after the grace period).
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
