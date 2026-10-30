import 'dart:async' show FutureOr;
import 'dart:io' show File;
import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show FileImage, ImageProvider, MemoryImage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/analysis/analysis.dart';
import 'package:pure_live/app/background/tone/background_frames.dart' show backgroundVideoFrameProvider;
import 'package:pure_live/app/background/tone/background_thumbnails.dart'
    show backgroundClipStillsProvider, backgroundClipUri;
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// The colour a picture with transparent parts is measured over.
///
/// The window paints this before the theme resolves; it only changes how such
/// a picture is read, never which one is painted, so it stays out of the cache
/// key.
const Color kBackgroundAnalysisUnderlay = Color(0xFF101418);

/// The media fields that change what is painted, and nothing that changes
/// only how it is painted: switching a scrim or a slider must not decode the
/// wallpaper again.
typedef BackgroundMediaSelection = ({
  BackgroundKind kind,
  Color solid,
  List<Color> gradient,
  List<double>? stops,
  int deg,
  String imagePath,
  String imageUrl,
  String videoPath,
  String videoUrl,
});

/// The current wallpaper's media selection.
final backgroundMediaProvider = Provider<BackgroundMediaSelection>((ref) {
  final settings = ref.watch(backgroundSettingsProvider);
  return (
    kind: settings.kind,
    solid: settings.solidColor,
    gradient: settings.gradientColors,
    stops: settings.gradientStops,
    deg: settings.gradientDeg,
    imagePath: settings.imagePath,
    imageUrl: settings.imageUrl,
    videoPath: settings.videoPath,
    videoUrl: settings.videoUrl,
  );
});

/// The wallpaper's identity: what the analysis is cached and the tone
/// hysteresis is remembered under. A file carries its modification time, so
/// replacing the file behind a saved path re-measures it.
final backgroundMediaIdentityProvider = Provider<String>((ref) {
  final media = ref.watch(backgroundMediaProvider);
  if (media.kind == BackgroundKind.image && media.imagePath.isNotEmpty) {
    return 'image:${media.imagePath}@${_modifiedMs(media.imagePath)}';
  }
  if (media.kind == BackgroundKind.video && media.videoPath.isNotEmpty) {
    return 'video:${media.videoPath}@${_modifiedMs(media.videoPath)}';
  }
  return switch (media.kind) {
    BackgroundKind.none => 'none',
    BackgroundKind.solid => 'solid:${media.solid.toARGB32()}',
    BackgroundKind.gradient =>
      'gradient:${[for (final color in media.gradient) color.toARGB32()].join(',')}'
          '|${media.stops?.join(',') ?? ''}|${media.deg}',
    BackgroundKind.image => 'image:${media.imageUrl}',
    BackgroundKind.video => 'video:${media.videoUrl}',
  };
});

/// The process's measurements, so going back to a wallpaper does not decode it
/// again. Bounded and in memory: a new run re-measures once per wallpaper.
final backgroundAnalysisCacheProvider = Provider<BackgroundAnalysisCache>((ref) {
  final cache = BackgroundAnalysisCache();
  ref.onDispose(cache.clear);
  return cache;
});

/// What the wallpaper measures: brightness distribution, 3×3 regions and the
/// representative colours the tone and the scrim are decided from.
///
/// Null while there is nothing to measure — no wallpaper, a broken file, a
/// clip whose still has not been taken — which keeps the viewer's own theme.
final backgroundAnalysisProvider = FutureProvider<BackgroundAnalysisResult?>((ref) async {
  final media = ref.watch(backgroundMediaProvider);
  switch (media.kind) {
    case BackgroundKind.none:
      return null;
    case BackgroundKind.solid:
      return backgroundAnalyzeGradient(
        colors: [media.solid],
        stops: const [0, 1],
        deg: 0,
        underlay: kBackgroundAnalysisUnderlay,
      );
    case BackgroundKind.gradient:
      return backgroundAnalyzeGradient(
        colors: media.gradient,
        stops: media.stops,
        deg: media.deg,
        underlay: kBackgroundAnalysisUnderlay,
      );
    case BackgroundKind.image:
      final provider = _imageProvider(media.imagePath, media.imageUrl);
      if (provider == null) return null;
      final identity = ref.watch(backgroundMediaIdentityProvider);
      return await _cached(
        ref,
        backgroundAnalysisKey(identity: identity, modifiedMs: _modifiedMs(media.imagePath)),
        () => backgroundAnalyzeImageProvider(provider, underlay: kBackgroundAnalysisUnderlay),
      );
    case BackgroundKind.video:
      final uri = backgroundClipUri(path: media.videoPath, url: media.videoUrl);
      if (uri == null) return null;
      final address = uri.toString();
      // A still already on disk is the stable sample. Otherwise the frame the
      // playing wallpaper renders stands in: the headless engine capture is
      // not reliable on every platform, and the surface capture that feeds
      // this frame is. That frame is remembered as the next still.
      final still = ref.read(backgroundClipStillsProvider).stored(address);
      if (still != null) {
        return await _cached(
          ref,
          backgroundAnalysisKey(identity: address, modifiedMs: _modifiedMs(still)),
          () => backgroundAnalyzeImageProvider(
            FileImage(File(still)),
            underlay: kBackgroundAnalysisUnderlay,
            source: BackgroundSampleSource.videoStill,
          ),
        );
      }
      final frame = ref.watch(backgroundVideoFrameProvider);
      if (frame == null || frame.uri != address) return null;
      return await backgroundAnalyzeImageProvider(
        MemoryImage(frame.bytes),
        underlay: kBackgroundAnalysisUnderlay,
        source: BackgroundSampleSource.videoFrame,
      );
  }
});

/// Measures [measure] unless the cache already holds [key].
Future<BackgroundAnalysisResult?> _cached(
  Ref ref,
  String key,
  FutureOr<BackgroundAnalysisResult?> Function() measure,
) async {
  final cache = ref.read(backgroundAnalysisCacheProvider);
  final hit = cache.get(key);
  if (hit != null) return hit;
  final result = await measure();
  if (result != null) cache.put(key, result);
  return result;
}

/// The picture the wallpaper paints: an uploaded file first, then a URL.
ImageProvider? _imageProvider(String path, String url) {
  if (path.isNotEmpty && File(path).existsSync()) return FileImage(File(path));
  return url.isNotEmpty ? cachedImage(url) : null;
}

/// The file's modification time, or 0 for a path that is not a local file.
int _modifiedMs(String path) {
  if (path.isEmpty) return 0;
  try {
    return File(path).statSync().modified.millisecondsSinceEpoch;
  } on Object {
    return 0;
  }
}
