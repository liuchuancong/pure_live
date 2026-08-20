import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';

/// Holds Android CPU/Wi-Fi resources only while user-initiated background
/// playback is active. The foreground media service remains the primary
/// process-lifetime mechanism.
class BackgroundPlaybackService {
  static const _channel = MethodChannel('pure_live/background_playback');
  static bool sleepSessionActive = false;
  static bool audioOnlySessionActive = false;
  static bool? _appliedKeepAlive;
  static final LatestAsyncValueQueue<bool> _keepAliveTransitions = LatestAsyncValueQueue<bool>(_applyKeepAlive);

  static Future<void> setKeepAlive(bool enabled) async {
    if (!Platform.isAndroid) return;
    if (!_keepAliveTransitions.isRunning && _appliedKeepAlive == enabled) return;
    await _keepAliveTransitions.submit(enabled);
  }

  static Future<void> _applyKeepAlive(bool enabled) async {
    if (_appliedKeepAlive == enabled) return;
    try {
      await _channel.invokeMethod<void>('setKeepAlive', {'enabled': enabled});
      _appliedKeepAlive = enabled;
    } on PlatformException {
      // Older installations do not expose this channel yet.
      _appliedKeepAlive = enabled;
    }
  }
}
