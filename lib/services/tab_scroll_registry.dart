import 'package:flutter/widgets.dart';

/// Registry of the primary [ScrollController] per bottom-nav branch.
///
/// Why: `StatefulShellRoute.indexedStack` keeps every branch alive, so
/// switching tabs resumes the previous scroll position. Product behavior
/// wants each tab tap to land at the top of that tab's screen.
///
/// Tab screens register their primary scroll view's controller here (each
/// tab root is the branch's primary scrollable, so one controller per branch
/// is enough — nested lists inside a tab don't use the primary controller).
///
/// The nav shell looks the controller up on tap and scrolls to 0.
class TabScrollRegistry {
  TabScrollRegistry._();

  static final Map<int, ScrollController> _controllers = {};

  /// Register (or replace) the controller for a tab branch.
  static void register(int branchIndex, ScrollController controller) {
    _controllers[branchIndex] = controller;
  }

  static void unregister(int branchIndex, ScrollController controller) {
    // Only remove if it's still the same instance (avoids racing a
    // replacement registration during hot reload).
    if (identical(_controllers[branchIndex], controller)) {
      _controllers.remove(branchIndex);
    }
  }

  /// Returns true if a registered controller exists and was moved.
  static bool scrollToTop(int branchIndex, {bool animated = true}) {
    final controller = _controllers[branchIndex];
    if (controller == null || !controller.hasClients) return false;

    final position = controller.position;
    if (position.pixels <= 0) return false;

    if (animated && position.maxScrollExtent > 0) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      controller.jumpTo(0);
    }
    return true;
  }
}
