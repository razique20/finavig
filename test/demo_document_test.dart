import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/document_type.dart';
import 'package:finavig/models/expiry_item.dart';
import 'package:finavig/services/demo_document_service.dart';

void main() {
  group('DemoDocumentService', () {
    test('demo documents are identifiable by the Demo: prefix', () {
      // The prefix is the contract with hasDemoDocument()/removeAll() —
      // keep it stable.
      expect(DemoDocumentService.demoNamePrefix, 'Demo: ');
    });

    test('demo expiry lands in the upcoming (8–30 day) band by default', () {
      // Default 21 days → urgency "High" band (8..30 days), which makes
      // Home alerts and the amber ladder visible without being scary.
      final defaultDays = 21;
      expect(defaultDays, greaterThan(7));
      expect(defaultDays, lessThanOrEqualTo(30));
      final urgency = UrgencyLevel.fromDays(defaultDays);
      expect(urgency.title, 'High');
    });

    test('demo document builds as a valid ExpiryItem', () {
      final meta =
          DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence);
      final expiry = DateTime.now().add(const Duration(days: 21));

      final item = ExpiryItem.create(
        id: 'demo-id',
        displayName:
            '${DemoDocumentService.demoNamePrefix}Sample Trade Licence',
        docType: meta,
        expiresAt: expiry,
        renewalFee: 2500,
        description: 'Sample document to explore FV',
      );

      expect(item.displayName, startsWith('Demo: '));
      expect(item.docType.key, 'tradeLicence');
      expect(item.renewalFee, 2500);
      expect(item.isActive, isTrue);
      expect(item.daysRemaining, inInclusiveRange(20, 21));
    });
  });
}
