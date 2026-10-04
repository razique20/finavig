import 'package:finavig/screens/money/forms/budget_form_sheets.dart';
import 'package:finavig/screens/money/forms/envelope_form_sheet.dart';
import 'package:finavig/screens/money/forms/transaction_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens [sheet] as a scrollable modal bottom sheet on a short surface with the
/// keyboard up, then asserts the layout did not overflow.
///
/// A RenderFlex overflow is reported as an exception during paint, so
/// [WidgetTester.takeException] is the assertion that catches it.
Future<void> _expectNoOverflow(
  WidgetTester tester,
  Widget sheet, {
  required String title,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 600);
  // Keyboard up before the sheet lays out — the exact condition that used to
  // raise "BOTTOM OVERFLOWED BY N PIXELS".
  tester.view.viewInsets = const FakeViewPadding(bottom: 320);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => sheet,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  expect(find.text(title), findsOneWidget);
  expect(tester.takeException(), isNull, reason: '$title overflowed');
  // Scrollable rather than clipped.
  expect(find.byType(SingleChildScrollView), findsWidgets);
}

void main() {
  testWidgets('Add Record sheet does not overflow when the keyboard is up',
      (tester) async {
    await _expectNoOverflow(
      tester,
      const TransactionFormSheet(),
      title: 'Add record',
    );
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Overall budget sheet does not overflow when the keyboard is up',
      (tester) async {
    await _expectNoOverflow(
      tester,
      const OverallBudgetFormSheet(),
      title: 'Set overall monthly budget',
    );
  });

  testWidgets('Category budget sheet does not overflow when the keyboard is up',
      (tester) async {
    await _expectNoOverflow(
      tester,
      const CategoryBudgetFormSheet(),
      title: 'Add budget',
    );
  });

  testWidgets('Envelope sheet does not overflow when the keyboard is up',
      (tester) async {
    await _expectNoOverflow(
      tester,
      const EnvelopeFormSheet(),
      title: 'New savings envelope',
    );
  });
}
