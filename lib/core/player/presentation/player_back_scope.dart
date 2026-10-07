import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/core/player/presentation/android_predictive_back_service.dart';

/// The routes that currently have a player on screen.
///
/// The service itself keeps one set of callbacks and a single enabled flag, and
/// its own behaviour is deliberately left alone — the live room and the
/// multiview grid depend on it. What this table adds is only the *counting*: a
/// scope that disposes must not switch the interception off while another player
/// route is still on screen, and must not clear the callbacks the route on screen
/// is using.
///
/// Entries are pruned against the live routes whenever one is added, so a route
/// that was popped without its scope disposing (an app-level pop) cannot pin the
/// interception on forever.
final Map<Route<dynamic>, _PlayerBackScopeState> _backScopeByRoute = <Route<dynamic>, _PlayerBackScopeState>{};

void _pruneBackScopes() {
  _backScopeByRoute.removeWhere((route, _) => !route.isActive);
}

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
  /// window).
  ///
  /// `canPop` is derived from this, and it is what Flutter's own back pipeline
  /// consults: while a presentation is active the route cannot be popped, so Back
  /// can only be answered by leaving that presentation. A host whose presentation
  /// is one of its own observables feeds this from that observable (see the
  /// recording player's boundary), which keeps this a single, stable widget.
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

  /// The callbacks this scope owns, so it can tell on the way out whether the
  /// service is still holding *its* handlers and not a successor's.
  late final VoidCallback _onInvoked = _handleNativeBack;
  late final VoidCallback _onStarted = _onBackStarted;
  late final ValueChanged<double> _onProgress = _onBackProgress;
  late final VoidCallback _onCancelled = _onBackCancelled;

  /// The route that owns this scope, resolved once: the route does not change
  /// while the element lives, and `dispose` can no longer read a valid context.
  Route<dynamic>? _route;

  bool get _usesNativeBack => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (!_usesNativeBack) return;
    _nativeBack.initialize();
    _installCallbacks();

    // Own Android Back for the whole player route, not only after a
    // presentation observable has rebuilt. Registering once here removes the
    // transition window in which Flutter's own Activity callback could pop the
    // route before the presentation callback was installed.
    unawaited(_setNativeBackEnabled(true));
  }

  void _installCallbacks() {
    _nativeBack.onBackStarted = _onStarted;
    _nativeBack.onBackProgress = _onProgress;
    _nativeBack.onBackCancelled = _onCancelled;
    _nativeBack.onBackInvoked = _onInvoked;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_usesNativeBack) return;
    final route = ModalRoute.of(context) ?? _route;
    if (route == null) return;
    _route = route;
    _pruneBackScopes();
    _backScopeByRoute[route] = this;
    // A page that re-mounts its scope (the recording player swaps its whole
    // layout when it enters fullscreen) must keep owning Back afterwards, and the
    // outgoing scope must not be able to disarm it on the way out.
    _installCallbacks();
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
      final route = _route;
      if (route != null) _backScopeByRoute.remove(route);
      // Only clear the shared callbacks when this scope is the last player
      // standing: clearing them while another route is on screen is what made
      // Back fall through to the route pop — one press left the page from
      // fullscreen. `identical` keeps a successor's handlers intact.
      if (_backScopeByRoute.isEmpty && identical(_nativeBack.onBackInvoked, _onInvoked)) {
        _nativeBack.onBackStarted = null;
        _nativeBack.onBackProgress = null;
        _nativeBack.onBackCancelled = null;
        _nativeBack.onBackInvoked = null;
        // Disable unconditionally: dispose can race the asynchronous enable,
        // and leaving the callback registered would consume Back on Home.
        unawaited(_setNativeBackEnabled(false));
      }
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
