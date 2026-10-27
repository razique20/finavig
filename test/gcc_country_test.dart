import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/document_collection.dart';
import 'package:finavig/models/document_type.dart';
import 'package:finavig/models/gcc_country.dart';
import 'package:finavig/screens/documents/documents_filters.dart';
import 'package:finavig/services/gcc_authority_catalog.dart';

void main() {
  group('GccCountry Enum Tests', () {
    test('resolves country code correctly case-insensitively', () {
      expect(GccCountry.fromCode('AE'), GccCountry.uae);
      expect(GccCountry.fromCode('sa'), GccCountry.ksa);
      expect(GccCountry.fromCode('Kw'), GccCountry.kuwait);
      expect(GccCountry.fromCode('QA'), GccCountry.qatar);
      expect(GccCountry.fromCode('bh'), GccCountry.bahrain);
      expect(GccCountry.fromCode('OM'), GccCountry.oman);
      expect(GccCountry.fromCode('XX'), GccCountry.uae); // Fallback
      expect(GccCountry.fromCode(null), GccCountry.uae);
    });

    test('returns correct national ID labels per country', () {
      expect(GccCountry.uae.nationalIdLabel, 'Emirates ID');
      expect(GccCountry.ksa.nationalIdLabel, 'Iqama / National ID');
      expect(GccCountry.kuwait.nationalIdLabel, 'Civil ID');
      expect(GccCountry.qatar.nationalIdLabel, 'QID (Qatar ID)');
      expect(GccCountry.bahrain.nationalIdLabel, 'CPR (Central Population ID)');
      expect(GccCountry.oman.nationalIdLabel, 'Resident / National ID');
    });

    test('returns correct currency codes', () {
      expect(GccCountry.uae.currency, 'AED');
      expect(GccCountry.ksa.currency, 'SAR');
      expect(GccCountry.kuwait.currency, 'KWD');
      expect(GccCountry.qatar.currency, 'QAR');
      expect(GccCountry.bahrain.currency, 'BHD');
      expect(GccCountry.oman.currency, 'OMR');
    });
  });

  group('DocumentCollection Country Integration', () {
    test('defaults to AE country code', () {
      const collection = DocumentCollection(id: 'col-1', name: 'Test Co');
      expect(collection.countryCode, 'AE');
      expect(collection.country, GccCountry.uae);
    });

    test('parses and serializes country code correctly', () {
      final json = {
        'id': 'col-2',
        'name': 'Kuwait Logistics',
        'country_code': 'KW',
        'is_personal': false,
      };
      final collection = DocumentCollection.fromJson(json);
      expect(collection.countryCode, 'KW');
      expect(collection.country, GccCountry.kuwait);
      expect(collection.subtitle, contains('Kuwait'));

      final serialized = collection.toJson();
      expect(serialized['country_code'], 'KW');
    });
  });

  group('GccAuthorityCatalog Tests', () {
    test('suggests appropriate authorities for each country', () {
      final tradeLicenceMeta = DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence);
      final ejariMeta = DocumentTypeRegistry.instance.byEnum(DocumentType.ejari);

      expect(
        GccAuthorityCatalog.instance.suggestedAuthorityFor(tradeLicenceMeta, GccCountry.ksa),
        contains('Ministry of Commerce'),
      );
      expect(
        GccAuthorityCatalog.instance.suggestedAuthorityFor(tradeLicenceMeta, GccCountry.kuwait),
        contains('MOCI'),
      );
      expect(
        GccAuthorityCatalog.instance.suggestedAuthorityFor(ejariMeta, GccCountry.ksa),
        contains('Ejar Network'),
      );
    });

    test('returns country authority options list', () {
      final visaMeta = DocumentTypeRegistry.instance.byEnum(DocumentType.visa);
      final optionsKsa = GccAuthorityCatalog.instance.authorityOptionsFor(visaMeta, GccCountry.ksa);
      expect(optionsKsa, isNotEmpty);
      expect(optionsKsa.any((a) => a.contains('Jawazat')), isTrue);

      final optionsKuwait = GccAuthorityCatalog.instance.authorityOptionsFor(visaMeta, GccCountry.kuwait);
      expect(optionsKuwait, isNotEmpty);
      expect(optionsKuwait.any((a) => a.contains('Public Authority of Manpower') || a.contains('Interior')), isTrue);
    });
  });

  group('Document Filter Sheet GCC Localization', () {
    testWidgets('DocumentsActiveFiltersRow displays country-specific label', (tester) async {
      final emiratesId = DocumentTypeRegistry.instance.byEnum(DocumentType.emiratesId);

      // UAE: displays Emirates ID
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentsActiveFiltersRow(
              query: '',
              typeFilter: emiratesId,
              filter: DocFilter.all,
              country: GccCountry.uae,
              onClear: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('Emirates ID'), findsOneWidget);

      // KSA: displays Iqama / National ID
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentsActiveFiltersRow(
              query: '',
              typeFilter: emiratesId,
              filter: DocFilter.all,
              country: GccCountry.ksa,
              onClear: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('Iqama / National ID'), findsOneWidget);
    });

    testWidgets('showDocumentsFilterSheet displays localized document types and country badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDocumentsFilterSheet(
                    context: context,
                    currentStatus: DocFilter.all,
                    currentType: null,
                    country: GccCountry.ksa,
                  );
                },
                child: const Text('Open Filter'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Filter'));
      await tester.pumpAndSettle();

      // Country badge
      expect(find.text('🇸🇦 Saudi Arabia'), findsOneWidget);

      // First document type is Trade Licence -> localized to Commercial Registration (CR)
      expect(find.text('Commercial Registration (CR)'), findsOneWidget);

      // Drag ListView to reveal items below fold
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Iqama / National ID'), findsOneWidget);
    });
  });
}

