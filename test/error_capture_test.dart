import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/services/error_capture_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ErrorCaptureService', () {
    test('record captures message, context and stack head', () {
      final service = ErrorCaptureService.instance;

      service.record(
        StateError('boom'),
        StackTrace.current,
        context: 'test',
      );

      expect(service.hasErrors, isTrue);
      final entry = service.records.first;
      expect(entry.message, contains('boom'));
      expect(entry.context, 'test');
      expect(entry.stackHead, isNotNull);
      // Ring buffer is newest-first (timestamps can tie within a
      // microtask, so non-strict comparison).
      expect(
        service.records.first.timestamp
            .isBefore(service.records.last.timestamp),
        isFalse,
      );
    });

    test('ring buffer respects the max-records cap', () {
      final service = ErrorCaptureService.instance;

      for (var i = 0; i < ErrorCaptureService.maxRecords + 5; i++) {
        service.record(StateError('err-$i'), null, context: 'test');
      }

      expect(service.records.length, ErrorCaptureService.maxRecords);
      // Newest first.
      expect(service.records.first.message, contains('err-24'));
    });

    test('clear empties the log', () async {
      final service = ErrorCaptureService.instance;
      service.record(StateError('x'), null, context: 'test');
      expect(service.hasErrors, isTrue);

      await service.clear();
      expect(service.hasErrors, isFalse);
      expect(service.records, isEmpty);
    });
  });
}
