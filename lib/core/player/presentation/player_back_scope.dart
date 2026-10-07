import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/core/player/presentation/android_predictive_back_service.dart';

/// Route-local system-back handling for a player page.
///
/// A player page is not a plain page: it has presentations of its own —
/// fullscreen, the picture-in-picture window, the in-app small window — and the
/// system Back gesture has to leave *those* first instead of tearing the route
/// down. This scope owns exactly one route pop:
///
/// - while a presentation is active, Back leaves it and keeps the page;
/// - otherwise [onBackRequest] is asked, and only an unhandled request pops.
///
/// It exists in Core rather than beside one player because the interception it
/// depends on is not a Flutter-level affair: Android 13+ delivers Back to the
/// Activity, Flutter registers its own callback there at DEFAULT priority, and
/// the route is popped before any `PopScope` runs unless the host has registered
/// a PRIORITY_OVERLAY callback through [AndroidPredictiveBackService]. A player
/// page that only wraps itself in `PopScope` therefore looks correct and never
/// receives the event — which is why both the live room and the recording player
/// mount this scope instead.
///
/// Dialogs and bottom sheets stay above this scope, so Navigator closes them
/// before this callback is considered.
class PlayerBackScope extends StatefulWidget {
  const PlayerBackScope({
    super.key,
    required this.presentationActive,
    required this.onExitPresentation,
    required this.child,
    this.onBackRequest,
  });

  /// Whether a presentation currently owns the page (fullscreen, PiP, small
  /// window). Read on every Back, so it tracks the observables behind it.
  final bool presentationActive;

  /// Leaves that presentation. The page stays.
  final FutureOr<void> Function() onExitPresentation;

  /// Runs before a back with no presentation pops the route. Returning true
  /// consumes the gesture (for example, handing the feed to the small window
  /// keeps the page).
  final FutureOr<bool> Function()? onBackRequest;

  final Widget child;

  @override
  State<PlayerBackScope> createState() => _PlayerBackScopeState();
}

class _PlayerBackScopeState extends State<PlayerBackScope> {
  final AndroidPredictiveBackService _nativeBack = AndroidPredictiveBackService.instance;
  bool _handlingBack = false;

  bool get _usesNativeBack => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (!_usesNativeBack) return;
    _nativeBack.initialize();
    _nativeBack.onBackStarted = _onBackStarted;
    _nativeBack.onBackProgress = _onBackProgress;
    _nativeBack.onBackCancelled = _onBackCancelled;
    _nativeBack.onBackInvoked = _handleNativeBack;

    // Own Android Back for the whole player route, not only after a
    // presentation observable has rebuilt. Registering once here removes the
    // transition window in which Flutter's own Activity callback could pop the
    // route before the presentation callback was installed.
    unawaited(_setNativeBackEnabled(true));
  }

  Future<void> _setNativeBackEnabled(bool enabled) async {
    if (!_usesNativeBack) return;
    try {
      await _nativeBack.setEnabled(enabled);
    } on PlatformException {
      // PopScope remains the fallback when the host channel is unavailable.
    } on MissingPluginException {
      // Widget tests and non-standard embeddings use the Flutter fallback.
    }
  }

  void _onBackStarted() {}

  void _onBackProgress(double _) {}

  void _onBackCancelled() {}

  Future<void> _handleNativeBack() async {
    if (_handlingBack || !mounted) return;

    _handlingBack = true;
    try {
      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);

      // A dialog, sheet, or popup opened above the player owns the first Back.
      if (route?.isCurrent == false) {
        await navigator.maybePop();
        return;
      }

      if (widget.presentationActive) {
        await widget.onExitPresentation();
      } else {
        // The host owns "what does back mean here": a host that tracks its own
        // presentation itself (the recording player does) answers from
        // [onBackRequest] and reports whether it consumed the gesture.
        final handled = await widget.onBackRequest?.call() ?? false;
        if (!handled) {
          await navigator.maybePop();
        }
      }
    } finally {
      _handlingBack = false;
    }
  }

  Future<void> _handlePresentationBack() async {
    if (_handlingBack || !mounted || !widget.presentationActive) return;
    _handlingBack = true;
    try {
      await widget.onExitPresentation();
    } finally {
      _handlingBack = false;
    }
  }

  @override
  void dispose() {
    if (_usesNativeBack) {
      _nativeBack.onBackStarted = null;
      _nativeBack.onBackProgress = null;
      _nativeBack.onBackCancelled = null;
      _nativeBack.onBackInvoked = null;
      // Disable unconditionally: dispose can race the asynchronous enable,
      // and leaving the callback registered would consume Back on Home.
      unawaited(_setNativeBackEnabled(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !widget.presentationActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.presentationActive) {
          unawaited(_handlePresentationBack());
        }
      },
      child: widget.child,
    );
  }
}
