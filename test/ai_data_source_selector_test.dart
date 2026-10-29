import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finavig/models/ai_data_source.dart';
import 'package:finavig/widgets/ai_data_source_selector.dart';

void main() {
  testWidgets(
    'toggles optional sources but keeps required and last source on',
    (tester) async {
      var selected = <AiDataSource>{AiDataSource.financialRecords};

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: AiDataSourceSelector(
                selectedSources: selected,
                requiredSources: const {AiDataSource.financialRecords},
                onChanged: (sources) => setState(() => selected = sources),
              ),
            ),
          ),
        ),
      );

      final financeTile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('ai-source-financialRecords')),
      );
      expect(financeTile.value, isTrue);
      expect(financeTile.onChanged, isNull);

      await tester.tap(find.byKey(const ValueKey('ai-source-documents')));
      await tester.pumpAndSettle();
      expect(selected, contains(AiDataSource.documents));

      await tester.tap(find.byKey(const ValueKey('ai-source-documents')));
      await tester.pumpAndSettle();
      expect(selected, {AiDataSource.financialRecords});

      await tester.tap(
        find.byKey(const ValueKey('ai-source-financialRecords')),
      );
      await tester.pumpAndSettle();
      expect(selected, {AiDataSource.financialRecords});
    },
  );
}
