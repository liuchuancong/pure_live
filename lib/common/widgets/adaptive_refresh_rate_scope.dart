import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pure_live/common/services/display_mode_service.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';

/// Requests the device's highest compatible mode only around real UI input.
///
/// Keeping Window.preferredRefreshRate pinned to 120/144 Hz for the entire
/// process doubles the frame budget pressure of every loading indicator and
/// image update. This coordinator gives touch/scroll/route animations the high
/// rate, then releases the window back to Android's variable/system policy
/// after the interaction settles.
class AdaptiveRefreshRateController {
  AdaptiveRefreshRateController._();

  // Keep one interaction burst on a stable mode. Android advises against
  // changing the window frame-rate hint multiple times per second because the
  // physical mode transition itself may drop a frame.
  static const settleDelay = Duration(milliseconds: 1500);
  static final LatestAsyncValueQueue<bool> _transitions = LatestAsyncValueQueue<bool>(
    (high) async => DisplayModeService.setHighRefreshRate(high),
  );

  static Timer? _settleTimer;
  static bool _enabled = false;
  static bool? _requestedHigh;
  static int _activePointers = 0;

  @visibleForTesting
  static bool get requestedHigh => _requestedHigh == true;

  static void setEnabled(bool enabled) {
    _enabled = enabled;
    _activePointers = 0;
    _settleTimer?.cancel();
    _requestHigh(false);
  }

  static void beginPointer() {
    if (!_enabled) return;
    _activePointers++;
    _settleTimer?.cancel();
    _requestHigh(true);
  }

  static void keepInteractive() {
    if (!_enabled) return;
    _requestHigh(true);
    if (_activePointers == 0) _scheduleSettle();
  }

  static void endPointer() {
    if (_activePointers > 0) _activePointers--;
    if (_enabled && _activePointers == 0) _scheduleSettle();
  }

  static void pause() {
    _activePointers = 0;
    _settleTimer?.cancel();
    _requestHigh(false);
  }

  static void _scheduleSettle() {
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDelay, () => _requestHigh(false));
  }

  static void _requestHigh(bool high) {
    final target = _enabled && high;
    if (_requestedHigh == target) return;
    _requestedHigh = target;
    unawaited(_transitions.submit(target));
  }
}

class AdaptiveRefreshRateScope extends StatefulWidget {
  const AdaptiveRefreshRateScope({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<AdaptiveRefreshRateScope> createState() => _AdaptiveRefreshRateScopeState();
}

class _AdaptiveRefreshRateScopeState extends State<AdaptiveRefreshRateScope> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdaptiveRefreshRateController.setEnabled(widget.enabled);
  }

  @override
  void didUpdateWidget(covariant AdaptiveRefreshRateScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      AdaptiveRefreshRateController.setEnabled(widget.enabled);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) AdaptiveRefreshRateController.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdaptiveRefreshRateController.pause();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      AdaptiveRefreshRateController.keepInteractive();
    } else if (notification is ScrollEndNotification) {
      AdaptiveRefreshRateController.endPointer();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => AdaptiveRefreshRateController.beginPointer(),
      onPointerMove: (_) => AdaptiveRefreshRateController.keepInteractive(),
      onPointerUp: (_) => AdaptiveRefreshRateController.endPointer(),
      onPointerCancel: (_) => AdaptiveRefreshRateController.endPointer(),
      child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
    );
  }
}
