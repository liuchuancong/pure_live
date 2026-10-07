import 'package:flutter/services.dart';

/// Bridges Android's native back dispatcher to the active live-room
/// presentation. Flutter's route PopScope remains the fallback for older or
/// unsupported embeddings, while Android 13+ gets a callback that runs before
/// the Navigator pops the room route.
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
