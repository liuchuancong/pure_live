import 'package:flutter/services.dart';

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
///
/// It does not:
///
/// - decide what back means (a route's back scope does)
/// - pop routes
class AndroidPredictiveBackService {
  AndroidPredictiveBackService._();

  static final AndroidPredictiveBackService instance = AndroidPredictiveBackService._();
  static const MethodChannel _channel = MethodChannel('pure_live/predictive_back');

  VoidCallback? onBackStarted;
  ValueChanged<double>? onBackProgress;
  VoidCallback? onBackCancelled;
  VoidCallback? onBackInvoked;

  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'backStarted':
        onBackStarted?.call();
        break;
      case 'backProgress':
        final arguments = call.arguments;
        if (arguments is Map) {
          onBackProgress?.call((arguments['progress'] as num?)?.toDouble() ?? 0);
        }
        break;
      case 'backCancelled':
        onBackCancelled?.call();
        break;
      case 'backInvoked':
        onBackInvoked?.call();
        break;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    initialize();
    await _channel.invokeMethod<void>('setEnabled', <String, Object>{'enabled': enabled});
  }
}
