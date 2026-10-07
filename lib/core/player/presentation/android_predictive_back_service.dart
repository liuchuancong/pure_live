import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One route's back callbacks, as a value.
///
/// The route table below compares entries by identity, so a scope that is
/// disposing can tell "my entry is still installed" from "another scope already
/// replaced it".
class AndroidPredictiveBackCallbacks {
  const AndroidPredictiveBackCallbacks({
    this.onBackStarted,
    this.onBackProgress,
    this.onBackCancelled,
    this.onBackInvoked,
  });

  final VoidCallback? onBackStarted;
  final ValueChanged<double>? onBackProgress;
  final VoidCallback? onBackCancelled;
  final VoidCallback? onBackInvoked;
}

/// Bridges Android's native back dispatcher to the player route on screen.
///
/// This is not a convenience wrapper around `PopScope`. On Android 13+ the
/// system back gesture and button are delivered to the Activity's
/// `OnBackInvokedDispatcher`, where Flutter registers its own callback at
/// DEFAULT priority — so the route is popped before `PopScope` is ever consulted
/// unless the host registers first. `MainActivity` therefore keeps a
/// PRIORITY_OVERLAY callback that forwards every back to Dart through this
/// channel; `PopScope` stays the fallback for older or unsupported embeddings.
///
/// Responsibilities:
///
/// - turn the native back callback into a Dart callback
/// - enable and disable that interception for the route that owns it
/// - keep the on-screen route's handler alive across widget rebuilds
///
/// It does not:
///
/// - decide what back means (a route's back scope does)
/// - pop routes
///
/// Handlers are registered per **route** and detached, never cleared wholesale.
/// A single set of callback fields that `dispose` nulled is what silently broke
/// Back here: the recording player swaps its whole layout when it enters
/// fullscreen, which re-mounts the scope, and the outgoing scope's `dispose` then
/// erased the callback the still-on-screen route needed. Back afterwards fell
/// through to the route pop — which is exactly "one press left the page instead
/// of leaving fullscreen".
class AndroidPredictiveBackService {
  AndroidPredictiveBackService._();

  static final AndroidPredictiveBackService instance = AndroidPredictiveBackService._();
  static const MethodChannel _channel = MethodChannel('pure_live/predictive_back');

  /// The route that currently owns Back → its callbacks.
  final Map<Route<dynamic>, AndroidPredictiveBackCallbacks> _owners =
      <Route<dynamic>, AndroidPredictiveBackCallbacks>{};

  bool _initialized = false;

  bool get hasOwner => _owners.isNotEmpty;

  /// The handler a back should reach right now: the current route's, falling
  /// back to the last attached one when no route reports itself current (during
  /// a transition, for instance).
  AndroidPredictiveBackCallbacks? _current() {
    Route<dynamic>? fallback;
    for (final entry in _owners.entries) {
      fallback ??= entry.key;
      if (entry.key.isCurrent) return entry.value;
    }
    return fallback == null ? null : _owners[fallback];
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Registers [callbacks] as the handler for [route], replacing whatever that
  /// route had before (a re-mounted scope) and leaving every other route alone.
  void attach(Route<dynamic> route, AndroidPredictiveBackCallbacks callbacks) {
    _owners[route] = callbacks;
  }

  /// Drops [callbacks] from [route], and only from there.
  ///
  /// A scope disposing after another scope already re-registered the same route
  /// would otherwise delete its successor's entry.
  void detach(Route<dynamic> route, AndroidPredictiveBackCallbacks callbacks) {
    if (!identical(_owners[route], callbacks)) return;
    _owners.remove(route);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    final owner = _current();
    // No route wants Back: leave it to the embedding instead of swallowing it.
    if (owner == null) return;
    switch (call.method) {
      case 'backStarted':
        owner.onBackStarted?.call();
        break;
      case 'backProgress':
        final arguments = call.arguments;
        if (arguments is Map) {
          owner.onBackProgress?.call((arguments['progress'] as num?)?.toDouble() ?? 0);
        }
        break;
      case 'backCancelled':
        owner.onBackCancelled?.call();
        break;
      case 'backInvoked':
        owner.onBackInvoked?.call();
        break;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    initialize();
    await _channel.invokeMethod<void>('setEnabled', <String, Object>{'enabled': enabled});
  }
}
