import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture, immutable;
import 'package:flutter/widgets.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart' show FfmpegKitExecutor;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:pure_live/shared/shared.dart' show appImageCache, cachedImage;

/// The platform serves its posters as HEIC (HEVC stills), which the engine's
/// codecs cannot read — a cover therefore goes through
/// [HongguoCoverCache] once, lands as a JPEG beside the app's cache, and is
/// plain decoding from then on.
final class HongguoCoverCache {
  HongguoCoverCache._();

  /// The one converter the module uses.
  static final HongguoCoverCache instance = HongguoCoverCache._();

  static final RegExp _heic = RegExp(r'\.heic(\?|$)', caseSensitive: false);

  /// Whether [url] names a HEIC still.
  static bool isHeic(String url) => _heic.hasMatch(url);

  final FfmpegKitExecutor _ffmpeg = FfmpegKitExecutor();
  Future<void>? _warming;
  final Map<String, Future<File?>> _inFlight = {};

  /// Covers that already failed this run. Their cards keep the fallback
  /// instead of downloading the still again on every rebuild; a listing's
  /// URL carries a fresh signature, so a later read tries anew.
  final Set<String> _failed = {};

  /// The JPEG rendition of [url], converting and caching it on first sight.
  /// Answers null when the cover cannot be read or converted; callers draw
  /// their fallback then.
  Future<File?> jpegFor(String url) {
    if (_failed.contains(url)) return Future<File?>.value();
    return _inFlight.putIfAbsent(url, () async {
      try {
        return await _convert(url);
      } on Object {
        _failed.add(url);
        return null;
      } finally {
        // The entry is bookkeeping; the conversion itself is the answer.
        final gone = _inFlight.remove(url);
        if (gone != null) unawaited(gone);
      }
    });
  }

  Future<File?> _convert(String url) async {
    final directory = Directory(p.join((await getTemporaryDirectory()).path, 'pure_live_hongguo_covers'));
    final target = File(p.join(directory.path, '${_keyOf(url)}.jpg'));
    if (target.existsSync()) return target;
    final source = await appImageCache.getSingleFile(url);
    await directory.create(recursive: true);
    final scratch = File(p.join(directory.path, '${_keyOf(url)}.$pid.jpg'));
    if (scratch.existsSync()) await scratch.delete();
    await (_warming ??= _ffmpeg.initialize());
    final execution = await _ffmpeg.start(
      arguments: ['-y', '-i', source.path, '-frames:v', '1', '-q:v', '3', scratch.path],
    );
    final code = await execution.exitCode;
    if (code != 0 || !scratch.existsSync()) {
      if (scratch.existsSync()) await scratch.delete();
      return null;
    }
    return await scratch.rename(target.path);
  }

  /// The cover behind the signature: the object path is stable, the query
  /// (expiry, signature) rotates with every listing, so the key is the path.
  static String _keyOf(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    // FNV-1a 32-bit: short, stable across runs, and collision-free enough for
    // a folder of a few hundred posters.
    var hash = 0x811c9dc5;
    for (final unit in path.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// The image provider for one cover: a HEIC still through the converter,
/// everything else straight to the app's image cache.
ImageProvider hongguoCoverImage(String url) =>
    HongguoCoverCache.isHeic(url) ? HongguoCoverImage(url) : cachedImage(url);

/// A HEIC cover drawn from its converted JPEG.
@immutable
final class HongguoCoverImage extends ImageProvider<HongguoCoverImage> {
  /// The provider for the cover at [url].
  const HongguoCoverImage(this.url);

  /// The signed cover URL.
  final String url;

  @override
  Future<HongguoCoverImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<HongguoCoverImage>(this);

  @override
  ImageStreamCompleter loadImage(HongguoCoverImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_frameOf(key.url));

  static Future<ImageInfo> _frameOf(String url) async {
    final file = await HongguoCoverCache.instance.jpegFor(url);
    if (file == null) throw StateError('cover conversion failed: $url');
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    try {
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    } finally {
      codec.dispose();
    }
  }

  @override
  bool operator ==(Object other) => other is HongguoCoverImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'HongguoCoverImage("$url")';
}
