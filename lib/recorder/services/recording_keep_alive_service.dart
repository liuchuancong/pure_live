import 'dart:io';

import 'package:flutter/services.dart';

class RecordingKeepAliveService {
  RecordingKeepAliveService._();
  static const MethodChannel _channel = MethodChannel('pure_live/recording_keep_alive');
  static bool _running = false;
  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    if (_running == enabled) return;
    try {
      await _channel.invokeMethod<void>(enabled ? 'start' : 'stop');
      _running = enabled;
    } catch (_) {}
  }

  static Future<void> start() => setEnabled(true);

  static Future<void> stop() => setEnabled(false);

  static bool get isRunning => _running;
}
