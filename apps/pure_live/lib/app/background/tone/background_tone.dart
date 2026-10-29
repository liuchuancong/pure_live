import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator_plus/palette_generator_plus.dart' show PaletteGenerator, contrastRatio;
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/background_thumbnails.dart';
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// What the app's text must be painted for over the current wallpaper.
///
/// The decision is made here, not taken from the palette's own suggestion:
/// the wallpaper's dominant colour is laid under the scrim the app will
/// actually paint (white in a light palette, black in the dark one) and both
/// candidates are scored with the WCAG contrast ratio. The higher score wins,
/// so the app switches to the palette whose ink reads on that backdrop.
final class BackgroundTone {
  /// The decision for [sample].
  const BackgroundTone({required this.sample, required this.dark});

  /// The sampled wallpaper colour, the most common one on an image or clip.
  final Color sample;

  /// Whether the pages need the light-ink palette (dark mode) over [sample].
  final bool dark;
}

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

/// The wallpaper's dominant colour; null when there is nothing to sample
/// (no wallpaper, a broken file) or the sample is still on its way.
///
/// Only the media identity is watched: the mask, the fit and the glass
/// settings change what is painted but not its colours, so dragging those
/// sliders must not decode the wallpaper again.
final backgroundSampleProvider = FutureProvider<Color?>((ref) async {
  final media = ref.watch(
    backgroundSettingsProvider.select(
      (s) => (
        kind: s.kind,
        solid: s.solidColor,
        gradient: s.gradientColors,
        imagePath: s.imagePath,
        imageUrl: s.imageUrl,
        videoPath: s.videoPath,
        videoUrl: s.videoUrl,
      ),
    ),
  );
  switch (media.kind) {
    case BackgroundKind.none:
      return null;
    case BackgroundKind.solid:
      return media.solid;
    case BackgroundKind.gradient:
      return _averageOf(media.gradient);
    case BackgroundKind.image:
      final provider = media.imagePath.isNotEmpty && File(media.imagePath).existsSync()
          ? FileImage(File(media.imagePath))
          : (media.imageUrl.isNotEmpty ? cachedImage(media.imageUrl) : null);
      return provider == null ? null : await _dominant(provider);
    case BackgroundKind.video:
      final frame = ref.watch(backgroundVideoFrameProvider);
      final uri = backgroundClipUri(path: media.videoPath, url: media.videoUrl);
      if (uri == null) return null;
      // A clip has no cover, so the engine's own screenshot takes one still
      // the first time the clip is seen; that frame is the reliable sample.
      // The frame the playing wallpaper decoded stands in when no still could
      // be taken.
      final still = await ref.read(backgroundClipStillsProvider).ensure(uri.toString());
      if (still != null) return await _dominant(FileImage(File(still)));
      if (frame == null || frame.uri != uri.toString()) return null;
      return await _dominant(MemoryImage(frame.bytes));
  }
});

/// The tone under the pages: null while there is no wallpaper or its colour
/// is not known yet, which keeps the viewer's own light/dark choice.
final backgroundToneProvider = Provider<BackgroundTone?>((ref) {
  final sample = ref.watch(backgroundSampleProvider).value;
  if (sample == null) return null;
  final scrim = ref.watch(backgroundSettingsProvider.select((s) => s.scrimOpacity));
  // The scrim is the palette's own: near-white in a light palette, black in
  // the dark one. Score the page each palette would actually paint.
  final lightPage = Color.alphaBlend(const Color(0xFFFFFFFF).withValues(alpha: scrim), sample);
  final darkPage = Color.alphaBlend(const Color(0xFF000000).withValues(alpha: scrim), sample);
  final lightInk = contrastRatio(lightPage, _darkInk);
  final darkInk = contrastRatio(darkPage, _lightInk);
  return BackgroundTone(sample: sample, dark: darkInk >= lightInk);
});

/// The ink each palette paints with, near its text colour: the decision is
/// about readability, so it is scored with what the eye will read.
const Color _darkInk = Color(0xFF14181C);
const Color _lightInk = Color(0xFFF4F6F8);

/// The most common colour of [provider], blacks and whites included: this is
/// a readability probe, not an accent picker, so the default filter that
/// drops them would hide a black wallpaper.
Future<Color?> _dominant(ImageProvider provider) async {
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      provider,
      size: const Size(48, 48),
      maximumColorCount: 8,
      filters: const [],
    );
    final dominant = palette.dominantColor;
    if (dominant != null) return dominant.color;
    final colors = palette.colors;
    return colors.isEmpty ? null : colors.first;
  } on Object {
    // An image that will not decode leaves the tone unknown; the viewer's
    // own brightness then stands.
    return null;
  }
}

/// The colour a gradient shows on balance: the mean of its stops.
Color? _averageOf(Iterable<Color> colors) {
  var count = 0;
  var red = 0.0;
  var green = 0.0;
  var blue = 0.0;
  var alpha = 0.0;
  for (final color in colors) {
    count++;
    red += color.r;
    green += color.g;
    blue += color.b;
    alpha += color.a;
  }
  if (count == 0) return null;
  return Color.from(alpha: alpha / count, red: red / count, green: green / count, blue: blue / count);
}
