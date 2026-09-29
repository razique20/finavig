import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One captured error: message, where it came from, when, and the first
/// frames of the stack. Small enough to persist in SharedPreferences.
class CapturedError {
  final String message;
  final String context; // 'flutter' | 'platform' | 'zone'
  final DateTime timestamp;
  final String? stackHead;

  const CapturedError({
    required this.message,
    required this.context,
    required this.timestamp,
    this.stackHead,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'context': context,
        'timestamp': timestamp.toIso8601String(),
        'stackHead': stackHead,
      };

  factory CapturedError.fromJson(Map<String, dynamic> json) {
    return CapturedError(
      message: json['message'] as String? ?? 'Unknown error',
      context: json['context'] as String? ?? 'flutter',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
              DateTime.now(),
      stackHead: json['stackHead'] as String?,
    );
  }
}

/// Local, dependency-free crash & error capture.
///
/// Installs two hooks — [FlutterError.onError] and the platform dispatcher's
/// [PlatformDispatcher.onError] — and keeps a bounded ring buffer of the
/// last errors, persisted to SharedPreferences so a crash on the previous
/// run is still visible on the next launch.
///
/// This is the v1 "black box": zero third-party dependencies, works offline.
/// When Sentry/Crashlytics is added later, forward from [record] — every
/// error in the app funnels through this one method.
class ErrorCaptureService {
  ErrorCaptureService._();

  static final ErrorCaptureService instance = ErrorCaptureService._();

  static const int maxRecords = 20;
  static const String _prefsKey = 'finavig.error_log.v1';

  final List<CapturedError> _records = [];

  /// Newest-first snapshot of captured errors (memory + persisted entries).
  List<CapturedError> get records => List.unmodifiable(_records);

  /// True when at least one error was captured since install.
  bool get hasErrors => _records.isNotEmpty;

  bool _installed = false;

  /// Install the global error hooks. Call once from `main()` before
  /// [runApp]. Idempotent.
  void install() {
    if (_installed) return;
    _installed = true;

    _loadPersisted();

    final originalFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack, context: 'flutter');
      // Preserve the framework's own reporting (console, dumpErrorToConsole).
      originalFlutterOnError?.call(details);
    };

    final dispatcher = PlatformDispatcher.instance;
    final originalPlatformOnError = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      record(error, stack, context: 'platform');
      // Delegate to the previous handler if any; otherwise report unhandled
      // so debug consoles still show the failure.
      return originalPlatformOnError?.call(error, stack) ?? false;
    };
  }

  /// Record one error. Never throws, never blocks: persistence is
  /// fire-and-forget. All app error paths funnel through here.
  void record(
    Object error,
    StackTrace? stack, {
    String context = 'flutter',
  }) {
    try {
      final entry = CapturedError(
        message: error.toString(),
        context: context,
        timestamp: DateTime.now(),
        stackHead: _stackHead(stack),
      );
      _records.insert(0, entry);
      while (_records.length > maxRecords) {
        _records.removeLast();
      }
      unawaited(_persist());
      debugPrint('[ErrorCapture] ($context) ${entry.message}');
    } catch (_) {
      // Never let the error recorder itself crash the app.
    }
  }

  /// First 6 frames of a stack, enough to locate the throw site in a report.
  static String? _stackHead(StackTrace? stack) {
    if (stack == null) return null;
    final lines = stack.toString().split('\n').take(6).join('\n');
    return lines.isEmpty ? null : lines;
  }

  void _loadPersisted() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        final raw = prefs.getString(_prefsKey);
        if (raw == null || raw.isEmpty) return;
        final decoded = jsonDecode(raw) as List<dynamic>;
        final persisted = decoded
            .map((e) => CapturedError.fromJson(e as Map<String, dynamic>))
            .toList();
        // Memory wins; fill remaining slots from disk (newest first).
        for (final entry in persisted) {
          if (_records.length >= maxRecords) break;
          _records.add(entry);
        }
      });
    } catch (_) {
      // Corrupt log — start clean.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _records.map((e) => e.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(jsonList));
    } catch (_) {
      // Best-effort persistence.
    }
  }

  /// Clear the log (e.g. after the user submits a support request).
  Future<void> clear() async {
    _records.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}
