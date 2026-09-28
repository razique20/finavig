import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Lightweight performance instrumentation for Finavig's critical flows:
/// cold start → Home, tab switch, document open, quick-action sheet open.
///
/// Two layers, both zero-cost when disabled:
///
/// 1. **DevTools timeline sections** — [trace] wraps a critical section in a
///    named [Timeline.startSync] block (visible in the DevTools timeline as
///    a colored span) and tags it with a logical "flow" via
///    [Timeline.timeSync]'s flow arguments so a flow can be followed across
///    async boundaries in the timeline view.
///
/// 2. **Frame-time monitor** — an optional [SchedulerBinding] observer that
///    samples frame build+raster durations in debug/profile builds and
///    reports jank (>16.7ms, severe >33ms) through [onSlowFrame] so a
///    regression shows up immediately during manual QA or a device-lab run.
class PerfTracingService with WidgetsBindingObserver {
  PerfTracingService._();

  static final PerfTracingService instance = PerfTracingService._();

  /// Named flows traced around the app. Used as timeline section names and
  /// as the metric keys in CI device-lab output.
  static const String flowColdStartToHome = 'cold_start_to_home';
  static const String flowTabSwitch = 'tab_switch';
  static const String flowDocumentOpen = 'document_open';
  static const String flowQuickActionSheet = 'quick_action_sheet';

  bool _frameMonitorAttached = false;
  final List<FrameTiming> _recentFrames = [];

  /// Called with every slow frame when the monitor is running (debug and
  /// profile builds only). Wire it to a logger in a device-lab harness.
  void Function(FrameTiming timing, FrameSeverity severity)? onSlowFrame;

  /// Wraps a synchronous critical section in a named timeline section.
  ///
  /// In release builds these events compile away, so this is free
  /// everywhere; in debug/profile the section shows up in DevTools.
  static T trace<T>(String sectionName, T Function() body) {
    if (kReleaseMode) return body();
    developer.Timeline.startSync(sectionName);
    try {
      return body();
    } finally {
      developer.Timeline.finishSync();
    }
  }

  /// Wraps an *async* critical section. The section opens on the current
  /// frame; the async work itself is not inside a sync span (that would
  /// block the timeline thread), but the start/end timestamps bracket the
  /// flow so DevTools shows the wall-clock duration.
  static Future<T> traceAsync<T>(
    String sectionName,
    Future<T> Function() body,
  ) async {
    if (kReleaseMode) return body();
    developer.Timeline.startSync(sectionName);
    try {
      return await body();
    } finally {
      developer.Timeline.finishSync();
    }
  }

  /// Emits an instant flow event so a flow's spans can be correlated in
  /// the DevTools timeline.
  static void markFlow(String flowName) {
    if (kReleaseMode) return;
    developer.Timeline.startSync('flow:$flowName');
    developer.Timeline.finishSync();
  }

  /// Attaches the frame-time monitor. Debug/profile only — a no-op in
  /// release, where the observer adds zero overhead because it is never
  /// registered.
  void startFrameMonitor() {
    if (kReleaseMode || _frameMonitorAttached) return;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _frameMonitorAttached = true;
  }

  void stopFrameMonitor() {
    if (!_frameMonitorAttached) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    WidgetsBinding.instance.removeObserver(this);
    _frameMonitorAttached = false;
  }

  /// Frames observed since the monitor started (bounded ring buffer).
  List<FrameTiming> get recentFrames =>
      List.unmodifiable(_recentFrames);

  /// Rough jank ratio since the monitor started: slow frames / total
  /// frames. Null when nothing has been measured yet.
  double? jankRatio() {
    if (_recentFrames.isEmpty) return null;
    final slow = _recentFrames
        .where((f) => f.buildDuration + f.rasterDuration > _frameBudget)
        .length;
    return slow / _recentFrames.length;
  }

  static const Duration _frameBudget = Duration(milliseconds: 16700 ~/ 1000);
  static const int _maxTrackedFrames = 300;

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _recentFrames.add(timing);
      if (_recentFrames.length > _maxTrackedFrames) {
        _recentFrames.removeAt(0);
      }

      final total = timing.buildDuration + timing.rasterDuration;
      if (total > const Duration(milliseconds: 33)) {
        onSlowFrame?.call(timing, FrameSeverity.severe);
      } else if (total > _frameBudget) {
        onSlowFrame?.call(timing, FrameSeverity.jank);
      }
    }
  }

  @override
  void didHaveMemoryPressure() {
    // Drop the ring buffer so the harness doesn't hold stale timings.
    _recentFrames.clear();
  }
}

/// How badly a frame missed the 16.7ms budget.
enum FrameSeverity {
  /// 16.7–33ms: one dropped frame.
  jank,

  /// >33ms: two or more dropped frames — visible hitch.
  severe,
}
