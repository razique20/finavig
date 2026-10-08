import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../dialogs/app_guide_dialog.dart';

/// Slim first-run banner on Home: "New here? Take the 1-minute guided tour."
/// Non-blocking by design — the old behavior auto-popped the full-screen
/// guide modal over Home (its barrier covered the tab bar too), which hid
/// content on Documents/Money. Now the guide is offered, not forced.
class FirstRunGuideBanner extends StatefulWidget {
  const FirstRunGuideBanner({super.key});

  @override
  State<FirstRunGuideBanner> createState() => _FirstRunGuideBannerState();
}

class _FirstRunGuideBannerState extends State<FirstRunGuideBanner> {
  bool _visible = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('hasSeenAppGuide') ?? false;
    final dismissed = prefs.getBool('firstRunGuideBannerDismissed') ?? false;
    if (!mounted) return;
    setState(() {
      _visible = !seen && !dismissed;
      _checked = true;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstRunGuideBannerDismissed', true);
    if (mounted) setState(() => _visible = false);
  }

  Future<void> _openGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstRunGuideBannerDismissed', true);
    if (mounted) setState(() => _visible = false);
    if (mounted) showAppGuideDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: FinavigGradients.primary,
          borderRadius: BorderRadius.circular(FinavigRadius.tile),
          boxShadow: [
            BoxShadow(
              color: FinavigColors.accent.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New here?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Take the 1-minute guided tour — or explore freely.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _dismiss,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('Later'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: _openGuide,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: FinavigColors.accent,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: const Text('Take the tour',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
