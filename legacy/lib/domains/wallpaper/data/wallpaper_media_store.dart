import 'dart:io';
import 'dart:typed_data';

import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/platform/app_path_manager.dart';

/// The file cache behind wallpaper backgrounds.
///
/// Three things about the first cut of video wallpapers are worth keeping in
/// mind, because two of them were silent black screens:
///
/// * Streaming the clip from the CDN. The background layer mounts while the
///   network is still settling, so a failed open leaves a plain black screen.
///   [download] saves the bytes once and the background plays a local file,
///   which cannot half-open.
/// * Using media_kit's default [VideoControllerConfiguration], which attaches
///   the Android surface before the video parameters are known - the documented
///   recipe for a one-pixel surface. The live player already works around that;
///   [wallpaperVideoControllerConfiguration] applies the same fix here.
///
/// Media are stored as **files**, not as a base64 blob in settings: a clip runs
/// to tens of megabytes, and a string that size would sit in memory and be
/// rewritten on every mask or fill-mode change. A picked file is copied in as
/// well, because on Android the picker hands out a cache path that the system
/// may evict while the setting still points at it.
class WallpaperMediaStore {
  const WallpaperMediaStore._();

  /// Downloads [url] once and returns the local path.
  ///
  /// A file that already exists and is non-empty is reused, so re-applying the
  /// same wallpaper costs nothing.
  static Future<String> download(String url, {void Function(int received, int total)? onProgress}) async {
    final Directory dir = await AppPathManager().wallpaperDir;
    final File file = File(p.join(dir.path, _fileName(url)));
    if (await file.exists() && await file.length() > 0) return file.path;

    await HttpClient.instance.download(
      url,
      file.path,
      header: wallpaperVideoHttpHeaders(),
      onReceiveProgress: onProgress,
    );
    return file.path;
  }

  /// Copies a user-picked file into the wallpaper directory and returns its
  /// path. A file already living there is returned unchanged.
  static Future<String> importFile(String sourcePath) async {
    final File source = File(sourcePath);
    final Directory dir = await AppPathManager().wallpaperDir;
    final File target = File(p.join(dir.path, _fileName(p.basename(sourcePath))));
    if (p.equals(target.path, source.path)) return target.path;
    await source.copy(target.path);
    return target.path;
  }

  /// Saves a fetched picture and returns its path.
  ///
  /// A random-image API hands over bytes rather than an address, so unlike
  /// [download] there is no URL to name the file after. It is named by a content
  /// hash instead, which makes keeping the same picture twice reuse one file,
  /// and suffixed with the real format taken from its magic number - the decoder
  /// sniffs content, but a wrong suffix confuses every other reader of the file.
  static Future<String> saveImageBytes(Uint8List bytes) async {
    final Directory dir = await AppPathManager().wallpaperDir;
    final String extension = imageFormatOf(bytes) ?? 'img';
    final File file = File(p.join(dir.path, 'random-${_contentHash(bytes)}.$extension'));
    if (await file.exists() && await file.length() > 0) return file.path;
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Lower-case format name of [bytes], by magic number; null when the bytes
  /// are not a picture at all.
  ///
  /// This is what keeps an API's JSON envelope or error page from being saved
  /// and applied as a background.
  static String? imageFormatOf(Uint8List bytes) {
    if (bytes.length < 12) return null;
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'jpg';
    // PNG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'png';
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'gif';
    // BMP
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'bmp';
    // WEBP: "RIFF"..."WEBP"
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    // HEIC/AVIF: an ISO base media "ftyp" box, distinguished by its brand.
    if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      final String brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (brand.startsWith('avi')) return 'avif';
      if (brand.startsWith('hei') || brand.startsWith('mif')) return 'heic';
    }
    return null;
  }

  /// FNV-1a over the bytes and their length: stable across runs and platforms,
  /// which `Object.hashCode` on a list is not.
  static String _contentHash(Uint8List bytes) {
    var hash = 0x811C9DC5;
    for (final int byte in bytes) {
      hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${hash.toRadixString(16).padLeft(8, '0')}-${bytes.length.toRadixString(16)}';
  }

  /// Whether [url] is already on disk, and where.
  static Future<String?> cachedPath(String url) async {
    final Directory dir = await AppPathManager().wallpaperDir;
    final File file = File(p.join(dir.path, _fileName(url)));
    if (await file.exists() && await file.length() > 0) return file.path;
    return null;
  }

  /// A safe, unique-ish file name derived from a URL or path.
  static String _fileName(String source) {
    final String raw = source.split('?').first.split('/').last;
    if (raw.isEmpty) return 'wallpaper.mp4';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}

/// The video-output configuration every wallpaper player should use.
///
/// Only the knobs that actually reach mpv are set here: this media_kit fork
/// always renders Android video through a `TextureRegistry.SurfaceProducer` and
/// drives the surface from the decoded video parameters, so the
/// surface-timing options have no consumer in it.
VideoControllerConfiguration wallpaperVideoControllerConfiguration() =>
    VideoControllerConfiguration(hwdec: Platform.isMacOS ? 'no' : null, enableHardwareAcceleration: !Platform.isMacOS);

/// Headers the wallpaper CDN expects, on both the download and the stream.
///
/// Without them the CDN answers 403 and mpv never produces a frame - the
/// background stays black with no other symptom.
Map<String, String> wallpaperVideoHttpHeaders() => const <String, String>{
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
  'Referer': 'https://www.itab.link/',
};
