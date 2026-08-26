import 'dart:async';

import 'package:flutter/services.dart';

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
    if (_initialized) {
      return;
    }

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
          final progress = (arguments['progress'] as num?)?.toDouble() ?? 0.0;

          onBackProgress?.call(progress);
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

    await _channel.invokeMethod<void>('setEnabled', <String, dynamic>{'enabled': enabled});
  }

  Future<bool> isEnabled() async {
    initialize();

    return await _channel.invokeMethod<bool>('isEnabled') ?? false;
  }
}
