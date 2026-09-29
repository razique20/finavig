import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/services/connectivity_service.dart';
import 'package:finavig/services/user_data_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stub probe: scripted answers, no network.
class StubProbe implements ConnectivityProbe {
  bool online;

  StubProbe(this.online);

  @override
  Future<bool> isOnline() async => online;
}

void main() {
  group('ConnectivityService', () {
    test('starts online and reflects probe changes', () async {
      final service = ConnectivityService.instance;
      service.probe = StubProbe(true);

      await service.checkNow();
      expect(service.isOnline, isTrue);

      var notified = 0;
      service.addListener(() => notified++);

      // Probe flips to offline.
      service.probe = StubProbe(false);
      await service.checkNow();
      expect(service.isOnline, isFalse);
      expect(notified, 1);

      // A probe returning the same state must not notify again.
      await service.checkNow();
      expect(notified, 1);
    });

    test('probe failure keeps the last known state', () async {
      final service = ConnectivityService.instance;
      service.probe = StubProbe(true);
      await service.checkNow();

      service.probe = _ThrowingProbe();
      await service.checkNow();
      expect(service.isOnline, isTrue);
    });

    test('start/stop are idempotent', () {
      final service = ConnectivityService.instance;
      service.stop(); // no timer to stop
      service.start();
      service.start(); // second call is a no-op
      service.stop();
      service.stop(); // second stop is a no-op
    });
  });

  group('UserDataExportService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'userRole': 'Document Admin',
        'userPhone': '+971500000000',
      });
    });

    test('export payload carries the expected shape and profile fields',
        () async {
      final export = await UserDataExportService.instance.buildExport();

      expect(export['format'], 'finavig-user-data-export');
      expect(export['version'], 1);
      expect(export['exportedAt'], isNotNull);
      expect(export['documents'], isA<List<dynamic>>());
      expect((export['finance'] as Map<String, dynamic>).keys,
          containsAll(['transactions', 'budgets', 'envelopes', 'recurring']));

      final profile = export['profile'] as Map<String, dynamic>;
      expect(profile['userRole'], 'Document Admin');
      expect(profile['userPhone'], '+971500000000');
    });

    test('buildExportJson returns parseable JSON', () async {
      final json = await UserDataExportService.instance.buildExportJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['format'], 'finavig-user-data-export');
      expect(decoded['documents'], isA<List<dynamic>>());
    });
  });
}

class _ThrowingProbe implements ConnectivityProbe {
  @override
  Future<bool> isOnline() async => throw Exception('probe down');
}
