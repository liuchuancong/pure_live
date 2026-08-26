import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/modules/live_play/services/android_predictive_back_service.dart';

/// Route-local system-back handling for a live room.
///
/// Android:
/// Normal rooms remain immediately poppable.
///
/// Fullscreen / widescreen presentations block the route pop and restore
/// the normal room instead.
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
  final AndroidPredictiveBackService _predictiveBack = AndroidPredictiveBackService.instance;

  /// Prevent native Back and Flutter PopScope from handling the same
  /// presentation exit at the same time.
  bool _handlingBack = false;

  /// Whether native Android Back interception is currently enabled.
  bool _nativeBackEnabled = false;

  /// Whether this scope is currently mounted as the active Android
  /// presentation owner.
  bool _nativeCallbackAttached = false;

  /// Only Android needs the native MethodChannel.
  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();

    if (!_isAndroid) {
      return;
    }

    _predictiveBack.initialize();

    // This scope owns the native callback while it is mounted.
    _predictiveBack.onBackStarted = _handleNativeBackStarted;
    _predictiveBack.onBackProgress = _handleNativeBackProgress;
    _predictiveBack.onBackCancelled = _handleNativeBackCancelled;
    _predictiveBack.onBackInvoked = _handleNativeBack;

    _nativeCallbackAttached = true;

    unawaited(_syncNativeBack());
  }

  @override
  void didUpdateWidget(covariant LivePlayBackScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isAndroid) {
      return;
    }

    if (oldWidget.presentationActive != widget.presentationActive) {
      unawaited(_syncNativeBack());
    }
  }

  Future<void> _syncNativeBack() async {
    if (!_isAndroid || !_nativeCallbackAttached) {
      return;
    }

    final enabled = widget.presentationActive;

    if (_nativeBackEnabled == enabled) {
      return;
    }

    try {
      await _predictiveBack.setEnabled(enabled);

      if (!mounted) {
        return;
      }

      _nativeBackEnabled = enabled;
    } on PlatformException {
      // Native implementation unavailable.
      //
      // PopScope remains available as the Flutter fallback.
    } on MissingPluginException {
      // Native implementation unavailable.
      //
      // PopScope remains available as the Flutter fallback.
    }
  }

  /// Disables native Android Back interception.
  Future<void> _disableNativeBack() async {
    if (!_isAndroid || !_nativeBackEnabled) {
      return;
    }

    try {
      await _predictiveBack.setEnabled(false);
    } on PlatformException {
      // Ignore errors during dispose.
    } on MissingPluginException {
      // Ignore errors during dispose.
    } finally {
      _nativeBackEnabled = false;
    }
  }

  /// Android Predictive Back started.
  ///
  /// We intentionally do not exit presentation here.
  ///
  /// The actual presentation exit happens only after Android commits
  /// the Back gesture.
  void _handleNativeBackStarted() {
    if (!_isAndroid) {
      return;
    }

    if (!widget.presentationActive) {
      return;
    }

    // Reserved for future Flutter transition animation.
  }

  /// Android Predictive Back progress.
  ///
  /// progress:
  ///
  ///   0.0 -> gesture started
  ///   1.0 -> gesture committed
  ///
  /// The actual presentation state is not changed here. This prevents
  /// cancelling the gesture from leaving the player in an inconsistent
  /// fullscreen state.
  void _handleNativeBackProgress(double progress) {
    if (!_isAndroid) {
      return;
    }

    if (!widget.presentationActive) {
      return;
    }

    // Reserved for future presentation transition animation.
  }

  /// Android Predictive Back cancelled.
  ///
  /// Do nothing here because the presentation was never exited.
  void _handleNativeBackCancelled() {
    if (!_isAndroid) {
      return;
    }

    // Reserved for future presentation transition animation reset.
  }

  /// Handles Android native Back.
  ///
  /// This can be:
  ///
  /// - Android physical Back key
  /// - Android system Back
  /// - Android 13+ system Back
  /// - Android 14+ predictive-back gesture
  Future<void> _handleNativeBack() async {
    if (_handlingBack) {
      return;
    }

    if (!widget.presentationActive) {
      return;
    }

    _handlingBack = true;

    try {
      await widget.onExitPresentation();
    } finally {
      _handlingBack = false;

      if (mounted && _isAndroid) {
        await _syncNativeBack();
      }
    }
  }

  /// Handles Flutter-side Back.
  ///
  /// Used by:
  ///
  /// - Windows
  /// - macOS
  /// - Linux
  /// - iOS
  /// - Web
  /// - Android fallback
  ///
  /// When presentationActive is true, the route pop is blocked and the
  /// presentation is exited instead.
  Future<void> _handleFlutterBack() async {
    if (_handlingBack) {
      return;
    }

    if (!widget.presentationActive) {
      return;
    }

    _handlingBack = true;

    try {
      await widget.onExitPresentation();
    } finally {
      _handlingBack = false;

      if (mounted && _isAndroid) {
        await _syncNativeBack();
      }
    }
  }

  @override
  void dispose() {
    if (_isAndroid) {
      // Disable native interception before this route disappears.
      unawaited(_disableNativeBack());

      // AndroidPredictiveBackService is a singleton.
      //
      // Do not leave this route's callback attached after disposal.
      if (_nativeCallbackAttached) {
        _predictiveBack.onBackStarted = null;
        _predictiveBack.onBackProgress = null;
        _predictiveBack.onBackCancelled = null;
        _predictiveBack.onBackInvoked = null;

        _nativeCallbackAttached = false;
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      /// Normal room:
      ///
      ///   canPop = true
      ///   Navigator handles Back normally.
      ///
      /// Presentation:
      ///
      ///   canPop = false
      ///   Flutter blocks the route pop.
      ///   _handleFlutterBack() restores normal presentation.
      canPop: !widget.presentationActive,

      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.presentationActive) {
          unawaited(_handleFlutterBack());
        }
      },

      child: widget.child,
    );
  }
}
