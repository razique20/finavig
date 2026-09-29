import 'package:uuid/uuid.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import 'document_scanner_service.dart';

/// First-run sample data: adds one clearly-labelled demo document so new
/// users see Home, alerts, and the urgency ladder working instead of an
/// empty shell.
///
/// The demo document is a normal tracked document with a `Demo:` prefix —
/// one tap on remove deletes it for real (this service only finds and calls
/// `removeItem`). It syncs like any document; there is no special-casing
/// anywhere else in the app, which keeps the feature honest and simple.
class DemoDocumentService {
  DemoDocumentService._();

  static final DemoDocumentService instance = DemoDocumentService._();

  static const String demoNamePrefix = 'Demo: ';

  /// Add a demo document expiring in [daysUntilExpiry] days (default 21 —
  /// inside the 30-day "upcoming" band so urgency visuals are interesting
  /// but not alarming).
  Future<ExpiryItem> addDemoDocument({int daysUntilExpiry = 21}) async {
    final meta =
        DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence);
    final expiry = DateTime.now().add(Duration(days: daysUntilExpiry));

    final item = ExpiryItem.create(
      id: const Uuid().v4(),
      displayName: '${DemoDocumentService.demoNamePrefix}Sample Trade Licence',
      docType: meta,
      expiresAt: expiry,
      renewalFee: 2500,
      description:
          'Sample document to explore Finavig — tap "Remove document" '
          'in its detail screen to delete it.',
    );

    await DocumentScannerService.instance.addItem(item);
    return item;
  }

  /// True when at least one demo document is currently tracked.
  Future<bool> hasDemoDocument() async {
    final items = await DocumentScannerService.instance.getAllItems();
    return items.any((i) => i.displayName.startsWith(demoNamePrefix));
  }

  /// Remove every demo document (used when the user asks to clean up).
  Future<int> removeAll() async {
    final items = await DocumentScannerService.instance
        .getAllItems(includeExpired: true);
    var removed = 0;
    for (final item in items) {
      if (!item.displayName.startsWith(demoNamePrefix)) continue;
      await DocumentScannerService.instance.removeItem(item.id);
      removed++;
    }
    return removed;
  }
}
