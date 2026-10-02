import 'dart:io';

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
