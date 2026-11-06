import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture, immutable;
import 'package:flutter/widgets.dart';
import 'package:heic_native/heic_native.dart';
import 'package:live_cache/live_cache.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/shared/shared.dart' show cachedImage, liveCacheManager;

/// The platform serves its posters as HEIC (HEVC stills), which the engine's
/// codecs cannot read — a cover therefore goes through [HongguoCoverCache]
/// once, lands as a PNG in the app's cache, and is plain decoding from then
/// on.
///
/// Both halves live in `live_cache`: the signed source under a stable key
/// derived from the object path (so a fresh signature does not write a new
/// file), and the converted PNG under its own key with a longer life.
final class HongguoCoverCache {
  HongguoCoverCache._();

  /// The one converter the module uses.
  static final HongguoCoverCache instance = HongguoCoverCache._();

  static final RegExp _heic = RegExp(r'\.heic(\?|$)', caseSensitive: false);

  /// The signed source is only a stepping stone; the converted PNG is what
  /// later draws read.
  static const ImageCachePolicy _sourcePolicy = ImageCachePolicies.preview;

  /// The converted poster outlives the listing that named it.
  static const ImageCachePolicy _pngPolicy = ImageCachePolicies.liveRoomDetail;

  /// Whether [url] names a HEIC still.
  static bool isHeic(String url) => _heic.hasMatch(url);

  final Map<String, Future<File?>> _inFlight = {};

  /// Covers that already failed this run. Their cards keep the fallback
  /// instead of downloading the still again on every rebuild; a listing's
  /// URL carries a fresh signature, so a later read tries anew.
  final Set<String> _failed = {};

  /// The PNG rendition of [url], converting and caching it on first sight.
  /// Answers null when the cover cannot be read or converted; callers draw
  /// their fallback then.
  Future<File?> pngFor(String url) {
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
    final key = _keyOf(url);
    final existing = await liveCacheManager.image.existingFile(identity: 'hongguo-png:$key', policy: _pngPolicy);
    if (existing != null) {
      return existing;
    }
    final source = await liveCacheManager.image.fileFor(
      url: Uri.parse(url),
      policy: _sourcePolicy,
      cacheKey: 'hongguo-src:$key',
    );
    if (source == null) {
      return null;
    }
    final scratch = File(p.join(Directory.systemTemp.path, 'pure_live_heic_${pid}_$key.png'));
    if (scratch.existsSync()) {
      await scratch.delete();
    }
    try {
      final converted = await HeicNative.convert(source.path, scratch.path);
      if (!converted || !scratch.existsSync()) {
        return null;
      }
      return await liveCacheManager.image.putBytes(
        identity: 'hongguo-png:$key',
        policy: _pngPolicy,
        bytes: await scratch.readAsBytes(),
      );
    } finally {
      if (scratch.existsSync()) {
        await scratch.delete();
      }
    }
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
ImageProvider hongguoCoverImage(String url, {int? width, int? height}) => HongguoCoverCache.isHeic(url)
    ? HongguoCoverImage(url, width: width, height: height)
    : cachedImage(url, policy: ImageCachePolicies.liveRoomCover, width: width, height: height);

/// A HEIC cover drawn from its converted PNG.
@immutable
final class HongguoCoverImage extends ImageProvider<HongguoCoverImage> {
  /// The provider for the cover at [url], decoded into [width]×[height] when
  /// the caller asked for a box.
  const HongguoCoverImage(this.url, {this.width, this.height});

  /// The signed cover URL.
  final String url;

  /// The decode box's width, or null for the source size.
  final int? width;

  /// The decode box's height, or null for the source size.
  final int? height;

  @override
  Future<HongguoCoverImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<HongguoCoverImage>(this);

  @override
  ImageStreamCompleter loadImage(HongguoCoverImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_frameOf(key, decode));

  static Future<ImageInfo> _frameOf(HongguoCoverImage key, ImageDecoderCallback decode) async {
    final file = await HongguoCoverCache.instance.pngFor(key.url);
    if (file == null) throw StateError('cover conversion failed: ${key.url}');
    final buffer = await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
    // A resizing wrapper hands this provider a callback that refuses a second
    // target size, so the callback is used only when no box was asked for.
    final codec = key.width == null && key.height == null
        ? await decode(buffer)
        : await ui.instantiateImageCodecWithSize(
            buffer,
            getTargetSize: (intrinsicWidth, intrinsicHeight) {
              var targetWidth = key.width;
              var targetHeight = key.height;
              if (targetWidth != null && targetWidth > intrinsicWidth) {
                targetWidth = intrinsicWidth;
              }
              if (targetHeight != null && targetHeight > intrinsicHeight) {
                targetHeight = intrinsicHeight;
              }
              return ui.TargetImageSize(width: targetWidth, height: targetHeight);
            },
          );
    try {
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    } finally {
      codec.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is HongguoCoverImage && other.url == url && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(url, width, height);

  @override
  String toString() => 'HongguoCoverImage("$url")';
}
