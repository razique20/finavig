// Regression guard: with documents tracked and no urgent renewals, the gap
// between the categories bento and the "Next renewals" section must stay tight
// section spacing — no phantom blank area (the collapsed attention banner must
// not reserve space).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/screens/home_screen.dart';
import 'package:finavig/theme/app_theme.dart';

void main() {
  testWidgets('no phantom gap between categories grid and next renewals',
      (tester) async {
    // Device-like viewport.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Two far-future documents (like the real device) → no attention banner,
    // no expired alert; renewals section renders right under the grid.
    final far = DateTime.now().add(const Duration(days: 361));
    final far2 = far.add(const Duration(days: 2));
    String docJson(DateTime d) {
      final y = d.year;
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '{"collectionId":"personal","id":"doc-$y$day",'
          '"displayName":"Driving Licence","docType":"drivingLicence",'
          '"expiryDate":"$y-$m-$day","daysRemaining":361,"isActive":true,'
          '"urgencyPriority":0,"expiresAt":"${d.toIso8601String()}"}';
    }

    SharedPreferences.setMockInitialValues({
      // Mark the first-launch app guide as seen so its overlay never covers
      // the layout this test measures.
      'hasSeenAppGuide': true,
      'local_documents_v1': jsonEncode([
        jsonDecode(docJson(far)),
        jsonDecode(docJson(far2)),
      ]),
    });

    await tester.pumpWidget(
      MaterialApp(theme: FinavigTheme.light(), home: const HomeScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Seeding worked and the renewals section is visible.
    expect(find.textContaining('Next renewals'), findsOneWidget);
    expect(find.text('This month'), findsNothing);

    // The categories bento ends with the full-width Scan CTA card.
    final scanCard = find
        .ancestor(of: find.text('Scan'), matching: find.byType(Material))
        .first;
    final gridBottom = tester.getBottomRight(scanCard).dy;
    final titleTop = tester.getTopLeft(find.textContaining('Next renewals')).dy;

    // Tight section spacing only — a stale/collapsed section must never
    // reserve a blank band here.
    expect(titleTop - gridBottom, lessThan(60),
        reason:
            'Gap between the categories grid and Next renewals should be small '
            'section spacing, got ${titleTop - gridBottom}px');
  });
}
