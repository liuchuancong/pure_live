import 'dart:async' show Future;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core/media_core.dart'
    show
        EngineOption,
        KernelOptions,
        PlayerConfig,
        PlayerHandle,
        PlayerHandleEngineOptions,
        PlayerHandleLifecycle,
        PlayerHandlePlayback,
        PlayerKernel,
        PlayerScreenshot,
        PlayerSource,
        ScreenshotFormat,
        ScreenshotOptions,
        ScreenshotRoute,
        SourceFormat,
        SourceId,
        SourceProtocol,
        SourceType;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitAdapterFactory;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show storagePathsProvider;

/// The preference the clip-to-still mapping is kept under.
const String kBackgroundClipStillsKey = 'background.stills';

/// Where a still is taken from: a second in, past most intros.
const Duration _kStillPosition = Duration(seconds: 1);

/// How long the headless player is given to open the clip.
const Duration _kOpenTimeout = Duration(seconds: 20);

/// How often a capture is retried while the decoder has not produced a frame
/// yet, and how long between tries: the player opens asynchronously and the
/// seek's frame arrives a moment later.
const int _kCaptureAttempts = 6;
const Duration _kCaptureRetry = Duration(milliseconds: 250);

/// How wide the kept still is: wide enough for a palette sample and a download
/// row's poster, small enough to decode on every page.
const int _kStillWidth = 320;

/// The clip the settings name, the same resolution the wallpaper paints.
Uri? backgroundClipUri({required String path, required String url}) {
  if (path.isNotEmpty && File(path).existsSync()) return Uri.file(path);
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
  return uri;
}

/// The stills taken from wallpaper clips.
///
/// A clip a viewer uploaded or linked to has no cover, and the wallpaper's
/// text tone needs one colour from it before the clip has decoded a frame.
/// The still is the mpv engine's own screenshot — the same capture a playing
/// wallpaper hands its tone reader — taken by a headless player seeked a
/// second in, and kept as a small PNG under the data area. The clip's own
/// address keys it, so a clip is captured once, whether it arrived by being
/// applied or by being downloaded. A failed capture is not retried in the same
/// run: the live frame the wallpaper decodes is the fallback then.
final class BackgroundClipStills {
  BackgroundClipStills(this._ref);

  final Ref _ref;

  /// Address → file. Read lazily; a still whose file has gone is dropped.
  Map<String, String>? _mapping;

  /// Captures in flight, so two callers asking for one clip share one player.
  final Map<String, Future<String?>> _pending = {};

  /// Addresses whose capture failed; asking again in this run would only fail
  /// again.
  final Set<String> _failed = {};

  int _serial = 0;

  /// The still already taken for [address]; null when there is none.
  String? stored(String address) {
    final mapping = _mappingOf();
    final path = mapping[address];
    if (path == null) return null;
    if (_usable(path)) return path;
    mapping.remove(address);
    return null;
  }

  /// The still for [address], capturing it when this is the first ask.
  ///
  /// Null means the clip could not be read — nothing was kept, and the caller
  /// falls back to whatever frame it has.
  Future<String?> ensure(String address) {
    final uri = _uriOf(address);
    if (uri == null) return Future<String?>.value();
    final still = stored(address);
    if (still != null) return Future<String?>.value(still);
    if (_failed.contains(address)) return Future<String?>.value();
    return _pending[address] ??= _capture(address, uri).whenComplete(() => _pending.remove(address));
  }

  /// Keeps [bytes] — a frame the playing wallpaper rendered — as the still for
  /// [address].
  ///
  /// On a platform where mpv will not hand a headless frame back, the picture
  /// on screen is still a truthful sample. Remembering it gives the next run
  /// (and the download rows) a still without opening a second decoder. An
  /// existing still is never replaced.
  Future<String?> remember(String address, Uint8List bytes, {ScreenshotFormat format = ScreenshotFormat.png}) async {
    if (bytes.isEmpty) return null;
    final existing = stored(address);
    if (existing != null) return existing;
    final path = await _writeBytes(bytes, format: format);
    if (path == null) return null;
    _mappingOf()[address] = path;
    await _persist();
    _failed.remove(address);
    return path;
  }

  /// Gives [to] the still already taken for [from].
  ///
  /// Applying a downloaded clip copies it into the app's own media folder,
  /// which makes a new address for the same frames. The still is copied rather
  /// than shared, so deleting either clip leaves the other's alone. Null when
  /// [from] has no still, or [to] already has one.
  Future<String?> carry({required String from, required String to}) async {
    final still = stored(from);
    if (still == null || stored(to) != null) return null;
    try {
      final directory = Directory(p.dirname(still));
      final copy = File(
        p.join(directory.path, 'clip-${DateTime.now().microsecondsSinceEpoch}-${_serial++}${p.extension(still)}'),
      );
      await File(still).copy(copy.path);
      _mappingOf()[to] = copy.path;
      await _persist();
      return copy.path;
    } on Object {
      // A still that will not copy is simply taken again when it is needed.
      return null;
    }
  }

  /// Drops the still for [address]: the clip it was taken from is gone.
  Future<void> forget(String address) async {
    final path = _mappingOf().remove(address);
    if (path == null) return;
    await _delete(path);
    await _persist();
  }

  /// The address as a playable uri: a `file:` path or a network address.
  static Uri? _uriOf(String address) {
    final uri = Uri.tryParse(address);
    if (uri == null) return null;
    return switch (uri.scheme) {
      'http' || 'https' || 'file' => uri,
      _ => null,
    };
  }

  Future<String?> _capture(String address, Uri uri) async {
    final kernel = PlayerKernel(
      options: const KernelOptions(autoAttachAudio: false, enablePool: false, enableRecovery: false),
    )..registerBackend(const MediaKitAdapterFactory().registration());
    PlayerHandle? handle;
    String? path;
    try {
      handle = await kernel.create(config: _config, source: _sourceOf(uri)).timeout(_kOpenTimeout);
      // A hardware decoder that cannot give its surface back makes mpv's
      // screenshot return nothing; the software path always has a frame to
      // encode. An engine that rejects the option keeps its default, and the
      // capture below reports the failure as before.
      try {
        await handle.applyEngineOptions(const [EngineOption('screenshot-sw', true)]);
      } on Object {
        // The default screenshot path is still worth trying.
      }
      final shot = await _shotOf(handle);
      if (shot != null) path = await _write(shot);
    } on Object {
      // A clip that will not open or decode leaves no still; the caller's
      // fallback still owns the tone.
    } finally {
      await _release(kernel, handle);
    }
    if (path == null) {
      _failed.add(address);
      return null;
    }
    _mappingOf()[address] = path;
    await _persist();
    return path;
  }

  /// The still out of a freshly opened player: seek a second in, then capture
  /// until the decoder has a frame to give.
  static Future<PlayerScreenshot?> _shotOf(PlayerHandle handle) async {
    try {
      await handle.seek(_kStillPosition);
    } on Object {
      // A clip shorter than the seek, or a server that will not seek, still
      // has its frame; the capture takes whatever is decoded.
    }
    for (var attempt = 0; attempt < _kCaptureAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_kCaptureRetry);
      final shot = await _screenshot(handle);
      if (shot != null) return shot;
    }
    return null;
  }

  /// One engine capture: mpv encodes the decoded frame itself, so no widget is
  /// on screen and none is needed.
  static Future<PlayerScreenshot?> _screenshot(PlayerHandle handle) async {
    try {
      return await handle.captureScreenshot(
        options: const ScreenshotOptions(
          format: ScreenshotFormat.jpeg,
          quality: 85,
          route: ScreenshotRoute.engine,
          timeout: Duration(seconds: 3),
        ),
      );
    } on Object {
      // A player torn down mid-capture answers nothing; the next attempt (or
      // the caller's fallback) decides.
      return null;
    }
  }

  /// Writes the capture as the still, shrinking it to [_kStillWidth] so a 4K
  /// clip's frame is a thumbnail rather than a megabyte on every page. A frame
  /// the shrinker cannot read is kept as the engine encoded it.
  Future<String?> _write(PlayerScreenshot shot) => _writeBytes(shot.bytes, format: shot.format);

  /// Writes [bytes] as a still in the same folder and shape as an engine
  /// capture.
  Future<String?> _writeBytes(Uint8List bytes, {required ScreenshotFormat format}) async {
    ui.Codec? codec;
    ui.Image? image;
    File? target;
    try {
      final directory = Directory(p.join(_ref.read(storagePathsProvider).data.path, 'background', 'thumbs'));
      await directory.create(recursive: true);
      Uint8List? shrunk;
      try {
        codec = await ui.instantiateImageCodec(bytes, targetWidth: _kStillWidth);
        final frame = await codec.getNextFrame();
        image = frame.image;
        shrunk = (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
      } on Object {
        shrunk = null;
      }
      final extension = shrunk != null ? 'png' : (format == ScreenshotFormat.png ? 'png' : 'jpg');
      target = File(p.join(directory.path, 'clip-${DateTime.now().microsecondsSinceEpoch}-${_serial++}.$extension'));
      await target.writeAsBytes(shrunk ?? bytes, flush: true);
      return _usable(target.path) ? target.path : null;
    } on Object {
      if (target != null) await _delete(target.path);
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  /// The player a still is taken with: muted, no audio driver, never paused by
  /// the app's own backgrounding — the capture may run while the window is
  /// hidden and nothing else listens to this player.
  static const PlayerConfig _config = PlayerConfig(
    name: 'clip-still',
    autoPlay: true,
    muted: true,
    volume: 0,
    enableAudio: false,
    pauseWhenBackgrounded: false,
    enableRecovery: false,
  );

  static PlayerSource _sourceOf(Uri uri) {
    final type = uri.scheme == 'file' ? SourceType.file : SourceType.remote;
    return PlayerSource.of(
      id: SourceId('clip-still:${uri.toString().hashCode}'),
      uri: uri,
      type: type,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: SourceFormat.fromUri(uri),
      title: 'clip-still',
    );
  }

  static Future<void> _release(PlayerKernel kernel, PlayerHandle? handle) async {
    if (handle != null) {
      try {
        await kernel.release(handle.id);
      } on Object {
        // Already gone; the dispose below still tears the kernel down.
      }
    }
    try {
      await kernel.dispose();
    } on Object {
      // A shutdown that is already running wins; nothing is left to do.
    }
  }

  Map<String, String> _mappingOf() => _mapping ??= _readMapping();

  static Map<String, String> _readMapping() {
    try {
      final raw = StoragePrefs.getString(kBackgroundClipStillsKey);
      if (raw == null || raw.isEmpty) return {};
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return {
        for (final entry in json.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
      }..removeWhere((_, path) => !_usable(path));
    } on Object {
      return {};
    }
  }

  Future<void> _persist() async {
    try {
      await StoragePrefs.setString(kBackgroundClipStillsKey, jsonEncode(_mappingOf()));
    } on Object {
      // A preference; a closed store loses the mapping, not the still.
    }
  }

  static bool _usable(String path) {
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0;
  }

  static Future<void> _delete(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on Object {
      // A still already gone needs no deleting.
    }
  }
}

/// The stills taken for wallpaper clips.
final backgroundClipStillsProvider = Provider<BackgroundClipStills>(BackgroundClipStills.new);
