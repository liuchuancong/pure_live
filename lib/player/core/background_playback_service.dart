import 'dart:io';

import 'package:flutter/services.dart';

/// Holds Android CPU/Wi-Fi resources only while user-initiated background
/// playback is active. The foreground media service remains the primary
/// process-lifetime mechanism.
class BackgroundPlaybackService {
  static const _channel = MethodChannel('pure_live/background_playback');

  static Future<void> setKeepAlive(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setKeepAlive', {'enabled': enabled});
    } on PlatformException {
      // Older installations do not expose this channel yet.
    }
  }
}
