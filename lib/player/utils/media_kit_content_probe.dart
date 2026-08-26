import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/player/interface/media_kit_player_accessor.dart';
import 'package:pure_live/player/utils/active_video_content_analyzer.dart';

/// Captures one decoder frame and downsizes it before active-content analysis.
///
/// The probe is invoked only a small, bounded number of times when a new live
/// source becomes stable. It never participates in frame rendering and never
/// installs an FFmpeg filter, preserving hardware decoding and steady-state
/// battery use.
class MediaKitContentProbe {
  const MediaKitContentProbe._();

  static const int analysisWidth = 192;

  static Future<ActiveVideoContentObservation?> capture(MediaKitPlayerAccessor accessor) async {
    final encoded = await accessor.mediaKitPlayer.safeScreenshot(format: 'image/jpeg', includeLibassSubtitles: false);
    if (encoded == null || encoded.isEmpty) return null;

    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(encoded, targetWidth: analysisWidth, allowUpscaling: false);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return null;
      final rgba = Uint8List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
      return const ActiveVideoContentAnalyzer().analyzeRgba(rgba, width: image.width, height: image.height);
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
