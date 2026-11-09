import 'package:flutter/material.dart';

import 'router.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';
import 'widgets/transaction_detection_card.dart';

class FinavigApp extends StatefulWidget {
  const FinavigApp({super.key});

  @override
  State<FinavigApp> createState() => _FinavigAppState();
}

class _FinavigAppState extends State<FinavigApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
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
      // TransactionDetectionOverlay — shows a confirmation card when a banking
      // notification is detected (slides in from the top above everything).
      // Clamp text scale between 0.85 and 1.25 so accessibility text scaling
      // remains readable without breaking card layouts or causing render flex overflows.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.25,
            ),
          ),
          child: TransactionDetectionOverlay(
            child: AppLockGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
