import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Which scene the [EmptyStateIllustration] shows. Each maps to a standard
/// Material icon so empty states read the same way as the rest of the app.
enum EmptyStateScene {
  /// Document page — "no documents tracked yet".
  document,

  /// Wallet — "no money records".
  wallet,

  /// Magnifier — "no search results".
  search,

  /// Upward trend — "no data to chart yet".
  growth,
}

extension _EmptyStateSceneIcon on EmptyStateScene {
  IconData get icon => switch (this) {
        EmptyStateScene.document => Icons.description_outlined,
        EmptyStateScene.wallet => Icons.account_balance_wallet_outlined,
        EmptyStateScene.search => Icons.search_rounded,
        EmptyStateScene.growth => Icons.trending_up_rounded,
      };
}

/// Standalone standard Material icon — the shared visual for every empty
/// state. Colours follow the app theme in light and dark mode and the mark
/// scales to any [size].
class EmptyStateIllustration extends StatelessWidget {
  final EmptyStateScene scene;
  final double size;

  const EmptyStateIllustration({
    super.key,
    this.scene = EmptyStateScene.document,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint =
        isDark ? FinavigColors.cyanAccent : FinavigColors.navyPrimary;

    // The box keeps the [size] footprint so the surrounding spacing is
    // unchanged, but the icon itself paints no background.
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          scene.icon,
          size: size * 0.5,
          color: tint,
        ),
      ),
    );
  }
}
