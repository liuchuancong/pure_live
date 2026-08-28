import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/modules/live_play/services/android_predictive_back_service.dart';

/// Route-local system-back handling for a live room.
///
/// Normal rooms remain immediately poppable. Fullscreen and widescreen
/// presentations block exactly one route pop and restore the normal room
/// instead. Dialogs and bottom sheets stay above this scope, so Navigator
/// closes them before this callback is considered.
class LivePlayBackScope extends StatefulWidget {
  const LivePlayBackScope({
    super.key,
    required this.presentationActive,
    required this.onExitPresentation,
    required this.child,
  });

  final bool presentationActive;
  final FutureOr<void> Function() onExitPresentation;
  final Widget child;

  @override
  State<LivePlayBackScope> createState() => _LivePlayBackScopeState();
}

class _LivePlayBackScopeState extends State<LivePlayBackScope> {
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

    // Own Android Back for the whole live-room route, not only after the
    // fullscreen observable has rebuilt. Registering once here removes the
    // transition window in which Flutter's Activity callback could pop the
    // room before the presentation callback was installed.
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

      // A dialog, sheet, or popup opened above the room owns the first Back.
      if (route?.isCurrent == false) {
        await navigator.maybePop();
        return;
      }

      if (widget.presentationActive) {
        await widget.onExitPresentation();
      } else {
        await navigator.maybePop();
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
