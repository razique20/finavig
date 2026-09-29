import 'package:flutter/material.dart';

import '../../services/connectivity_service.dart';
import '../../theme/app_theme.dart';

/// Slim banner pinned above the app shell when the device is offline.
///
/// The app is offline-first: every write queues locally and replays when
/// connectivity returns — the banner's whole job is to say so, so the user
/// reads "expected" instead of "broken". Hidden entirely while online;
/// animates in/out on state change. Returns a zero-height box when online
/// so layouts are unaffected.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 0,
    );
    final service = ConnectivityService.instance;
    _offline = !service.isOnline;
    if (_offline) _controller.value = 1;
    service.addListener(_onConnectivityChanged);
    WidgetsBinding.instance.addObserver(this);
    service.start();
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_onConnectivityChanged);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Phone-mode switches (Wi-Fi ↔ cellular, VPN up/down) rarely fire DNS
    // callbacks — re-probe when the app returns to the foreground.
    if (state == AppLifecycleState.resumed) {
      ConnectivityService.instance.checkNow();
    }
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    final offline = !ConnectivityService.instance.isOnline;
    if (offline == _offline) return;
    setState(() => _offline = offline);
    offline ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final height = _controller.value * 34;
        if (height == 0) return const SizedBox.shrink();
        return Container(
          height: height,
          color: isDark
              ? FinavigColors.warning.withOpacity(0.15)
              : FinavigColors.warning.withOpacity(0.12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 14,
                color: FinavigColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'Offline — changes are saved on device and will sync',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? FinavigColors.warning
                      : FinavigColors.warning,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
