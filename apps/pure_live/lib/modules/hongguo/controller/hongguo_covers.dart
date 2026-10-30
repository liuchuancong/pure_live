import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture, immutable;
import 'package:flutter/widgets.dart';
import 'package:heic_native/heic_native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:pure_live/shared/shared.dart' show appImageCache, cachedImage, installedImageCacheDirectory;

/// The platform serves its posters as HEIC (HEVC stills), which the engine's
/// codecs cannot read — a cover therefore goes through [HongguoCoverCache]
/// once, lands as a PNG under the app's image cache, and is plain decoding
/// from then on.
final class HongguoCoverCache {
  HongguoCoverCache._();

  /// The one converter the module uses.
  static final HongguoCoverCache instance = HongguoCoverCache._();

  static final RegExp _heic = RegExp(r'\.heic(\?|$)', caseSensitive: false);

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

  /// Where the converted stills live: `covers/` under the app's image cache,
  /// so the one folder the settings page measures, caps and clears holds every
  /// cached picture. The temporary directory stands in for a cover asked for
  /// before the boot installs the cache root.
  static Future<Directory> _coverDirectory() async {
    final root = installedImageCacheDirectory;
    if (root != null) return Directory(p.join(root.path, 'covers'));
    return Directory(p.join((await getTemporaryDirectory()).path, 'pure_live_hongguo_covers'));
  }

  Future<File?> _convert(String url) async {
    final directory = await _coverDirectory();
    final key = _keyOf(url);
    final target = File(p.join(directory.path, '$key.png'));
    if (target.existsSync()) return target;
    final source = await appImageCache.getSingleFile(url);
    await directory.create(recursive: true);
    // The scratch name carries the isolate so two runs never share a
    // half-written file; the rename into place is the commit.
    final scratch = File(p.join(directory.path, '$key.$pid.png'));
    if (scratch.existsSync()) await scratch.delete();
    final converted = await HeicNative.convert(source.path, scratch.path);
    if (!converted || !scratch.existsSync()) {
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

/// A HEIC cover drawn from its converted PNG.
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
    final file = await HongguoCoverCache.instance.pngFor(url);
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
