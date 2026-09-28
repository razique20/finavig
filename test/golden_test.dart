import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/widgets/shimmer_skeleton.dart';

/// Golden guards for the shimmer skeleton views — the loading state users
/// see on cold open of every main tab. A visual refactor that silently
/// changes these fails CI instead of shipping.
///
/// The pump pins one animation tick so the shimmer gradient lands in a
/// reproducible state. The theme is a plain [ThemeData] (no google_fonts
/// runtime fetch) so the goldens are hermetic on CI.
///
/// Goldens are committed under test/goldens/. Regenerate with:
///   flutter test --update-goldens test/golden_test.dart
void main() {
  testWidgets('Home skeleton golden', (tester) async {
    await _pumpSkeleton(tester, const HomeSkeletonView());
    await expectLater(
      find.byType(HomeSkeletonView),
      matchesGoldenFile('goldens/home_skeleton.png'),
    );
  });

  testWidgets('Documents skeleton golden', (tester) async {
    await _pumpSkeleton(tester, const DocumentsSkeletonView());
    await expectLater(
      find.byType(DocumentsSkeletonView),
      matchesGoldenFile('goldens/documents_skeleton.png'),
    );
  });

  testWidgets('Money skeleton golden', (tester) async {
    await _pumpSkeleton(tester, const MoneySkeletonView());
    await expectLater(
      find.byType(MoneySkeletonView),
      matchesGoldenFile('goldens/money_skeleton.png'),
    );
  });
}

/// Deterministic light theme without runtime font fetching — the skeleton
/// views carry layout, and the golden guards layout + structure.
ThemeData _goldenTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B2A4A)),
    brightness: Brightness.light,
  );
  return base.copyWith(textTheme: base.textTheme.apply());
}

Future<void> _pumpSkeleton(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.0;
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _goldenTheme(),
      home: Scaffold(body: child),
    ),
  );
  // Settle one animation tick so the shimmer gradient is in a fixed state.
  await tester.pump(const Duration(milliseconds: 250));
}
