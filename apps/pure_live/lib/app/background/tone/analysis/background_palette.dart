import 'dart:async' show Completer;
import 'dart:ui' as ui;
import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show ImageConfiguration, ImageProvider, ImageStreamListener, ResizeImage;
import 'package:palette_generator_plus/palette_generator_plus.dart' show EncodedImage, PaletteGenerator;

import 'package:pure_live/app/background/tone/analysis/background_models.dart';
import 'package:pure_live/app/background/tone/analysis/background_pixels.dart';

/// Decodes [provider] once and measures it, or returns null when the picture
/// cannot be read.
///
/// The same pixel buffer feeds both the luminance statistics and the palette
/// quantizer: [PaletteGenerator.fromImage] would read the image a second time,
/// and [PaletteGenerator.fromImageProvider] would not share its pixels at all.
Future<BackgroundAnalysisResult?> backgroundAnalyzeImageProvider(
  ImageProvider provider, {
  required Color underlay,
  int sampleWidth = kBackgroundAnalysisSampleWidth,
  Duration timeout = const Duration(seconds: 10),
  BackgroundSampleSource source = BackgroundSampleSource.image,
}) async {
  final resized = ResizeImage.resizeIfNeeded(sampleWidth, null, provider);
  final stream = resized.resolve(ImageConfiguration.empty);
  final completer = Completer<ui.Image>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image);
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  try {
    final image = await completer.future.timeout(timeout);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) return null;
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final measured = backgroundAnalyzeRgba(
      rgba: bytes,
      width: image.width,
      height: image.height,
      underlay: underlay,
      source: source,
    );
    final palette = await PaletteGenerator.fromByteData(
      EncodedImage(data, width: image.width, height: image.height),
      maximumColorCount: 8,
      // The default filter drops blacks, whites and muted reds, which hides a
      // black or white wallpaper from the very probe that reads it.
      filters: const [],
      runInIsolate: false,
    );
    final dominant = palette.dominantColor?.color ?? (palette.colors.isEmpty ? null : palette.colors.first);
    return dominant == null ? measured : measured.copyWithDominant(dominant);
  } on Object {
    // A picture that will not load or decode leaves the tone unknown; the
    // caller keeps the viewer's own theme.
    return null;
  } finally {
    stream.removeListener(listener);
  }
}
