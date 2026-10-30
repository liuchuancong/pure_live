import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The last frame the wallpaper video decoded, so the tone can be read off
/// it. Keyed by uri: a frame of the previous clip says nothing about the one
/// playing now.
final class BackgroundVideoFrame extends Notifier<({String uri, Uint8List bytes})?> {
  @override
  ({String uri, Uint8List bytes})? build() => null;

  /// Publishes [bytes] as the frame of [uri].
  void publish(String uri, Uint8List bytes) => state = (uri: uri, bytes: bytes);
}

/// The wallpaper video's sampled frame, written once per clip.
final backgroundVideoFrameProvider = NotifierProvider<BackgroundVideoFrame, ({String uri, Uint8List bytes})?>(
  BackgroundVideoFrame.new,
);
