import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/core/consts/background_source.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/background_config.dart';
import 'package:pure_live/core/network/image_cache_manager.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_media_store.dart';

/// The app background: its configuration, and the player behind a video one.
///
/// The configuration is one Hive value ([config]) so the whole background layer
/// can be watched with a single `Obx`. The video pipeline is *not* part of it:
/// the player, its controller and the poster frame captured while the live
/// player runs are runtime-only, and published as [videoController] /
/// [posterFrame] for the background layer to paint.
class BackgroundController extends GetxController {
  static const String configKey = 'backgroundConfig';

  /// Long-lived provider: the app's DI registers the instance, this is the stable accessor.
  static BackgroundController get to => Get.find<BackgroundController>();

  /// Live configuration, persisted as one JSON value.
  final Rx<BackgroundConfig> config = hiveObject<BackgroundConfig>(
    configKey,
    const BackgroundConfig(),
    fromJson: BackgroundConfig.fromJson,
    toJson: (value) => value.toJson(),
  );

  BackgroundConfig get state => config.v;

  /// Whether the background covers the page canvas, i.e. whether the app should
  /// stop painting its own scaffold colour.
  ///
  /// A separate flag so that a theme rebuild only happens when the canvas owner
  /// actually changes: the whole `GetMaterialApp` would otherwise be rebuilt on
  /// every mask or blur slider tick.
  final RxBool occupiesCanvas = const BackgroundConfig().hasBackground.obs;

  /// Whether [item] is what the background is showing right now.
  ///
  /// Colour and gradient entries have no URL to compare, so they match on their
  /// stops; a downloaded clip is matched by file name because it was applied
  /// from the local copy rather than the URL it came from.
  bool usesWallpaper(WallpaperItem item) {
    final stops = item.gradient?.map((stop) => colorFromHex(stop.color)).whereType<Color>().toList();
    final name = item.file.split('?').first.split('/').last;
    return switch (state.source) {
      BackgroundSource.none => false,
      BackgroundSource.color => stops != null && stops.isNotEmpty && stops.first == state.solidColor,
      BackgroundSource.gradient => stops != null && _sameColors(stops, state.gradientColors),
      BackgroundSource.image => state.imagePath == item.file || state.imagePath.endsWith('/$name'),
      BackgroundSource.networkImage => state.imageUrl == item.file,
      BackgroundSource.video => state.videoPath == item.file || state.videoPath.endsWith('/$name'),
      BackgroundSource.networkVideo => state.videoUrl == item.file,
    };
  }

  static bool _sameColors(List<Color> a, List<Color> b) =>
      a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((same) => same);

  /// The controller the background layer renders; null until a video
  /// wallpaper needs one.
  final Rxn<VideoController> videoController = Rxn<VideoController>();

  /// Frame captured from the wallpaper player before it was released.
  final Rxn<Uint8List> posterFrame = Rxn<Uint8List>();

  Player? _videoPlayer;

  /// Diagnostics subscriptions of the wallpaper player. A black background with
  /// no other symptom is mpv failing to load the clip; without these that
  /// failure is completely silent.
  final List<StreamSubscription<dynamic>> _wallpaperDiagSubs = <StreamSubscription<dynamic>>[];

  bool _wallpaperReadyLogged = false;

  @override
  void onInit() {
    super.onInit();
    occupiesCanvas.value = state.hasBackground;
    unawaited(reloadBackgroundVideo());
  }

  @override
  void onClose() {
    for (final sub in _wallpaperDiagSubs) {
      unawaited(sub.cancel());
    }
    _wallpaperDiagSubs.clear();
    unawaited(_videoPlayer?.dispose());
    _videoPlayer = null;
    videoController.value = null;
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  void setNone() => _apply(const BackgroundConfig());

  void setBoxFit(BoxFit fit) => _apply(state.copyWith(boxFit: fit));

  void setMaskOpacity(double opacity) => _apply(state.copyWith(maskOpacity: opacity.clamp(0.0, 1.0)));

  void setBlurSigma(double sigma) =>
      _apply(state.copyWith(blurSigma: sigma.clamp(0, BackgroundConfig.maxBlurSigma).toDouble()));

  void setSolidColor(Color color) => _apply(state.copyWith(source: BackgroundSource.color, solidColor: color));

  void setGradientColors(List<Color> colors) {
    if (colors.length < 2) return;
    _apply(state.copyWith(source: BackgroundSource.gradient, gradientColors: colors));
  }

  /// Applies one compiled-in colour/gradient entry from the wallpaper catalog.
  void setCatalogGradient(WallpaperItem item) {
    final stops = item.gradient;
    if (stops == null || stops.isEmpty) return;
    final colors = stops.map((stop) => colorFromHex(stop.color)).whereType<Color>().toList();
    if (colors.isEmpty) return;
    if (colors.length == 1) {
      setSolidColor(colors.first);
      return;
    }
    setGradientColors(colors);
  }

  /// A picture on the device - picked by the user or downloaded from a source.
  void setLocalImage(String path) {
    if (path.isEmpty) return;
    _apply(state.copyWith(source: BackgroundSource.image, imagePath: path, imageUrl: ''));
  }

  /// A stable remote picture, streamed through the shared image cache.
  void setNetworkImage(String url) {
    if (url.isEmpty) return;
    _apply(state.copyWith(source: BackgroundSource.networkImage, imageUrl: url, imagePath: ''));
  }

  void setVideoPath(String path) {
    if (path.isEmpty) return;
    _apply(state.copyWith(source: BackgroundSource.video, videoPath: path, videoUrl: ''));
  }

  /// A remote clip played directly. Prefer [applyNetworkVideo], which downloads
  /// first: a wallpaper that cannot half-open is the difference between a
  /// background and a black screen.
  void setNetworkVideo(String url) {
    if (url.isEmpty) return;
    _apply(state.copyWith(source: BackgroundSource.networkVideo, videoUrl: url, videoPath: ''));
  }

  /// Downloads [url] (or reuses the cached clip) and applies it as the
  /// background. Returns false when the download failed.
  Future<bool> applyNetworkVideo(String url, {void Function(int received, int total)? onProgress}) async {
    try {
      final path = await WallpaperMediaStore.download(url, onProgress: onProgress);
      setVideoPath(path);
      return true;
    } catch (error) {
      log('Wallpaper video download failed: $error', name: 'BackgroundController');
      return false;
    }
  }

  /// Applies a picture that arrived as bytes rather than as an address.
  ///
  /// A random-image API answers a different picture per request, so there is no
  /// URL to store: the bytes are written into the wallpaper directory and applied
  /// as a local picture, which also makes the choice survive a restart.
  Future<bool> applyNetworkImageBytes(Uint8List bytes) async {
    try {
      final path = await WallpaperMediaStore.saveImageBytes(bytes);
      setLocalImage(path);
      return true;
    } catch (error) {
      log('Wallpaper image save failed: $error', name: 'BackgroundController');
      return false;
    }
  }

  void _apply(BackgroundConfig next) {
    final previous = state;
    config.v = next;
    occupiesCanvas.value = next.hasBackground;
    final videoChanged =
        next.source != previous.source || next.videoPath != previous.videoPath || next.videoUrl != previous.videoUrl;
    if (videoChanged) unawaited(reloadBackgroundVideo());
  }

  // ---------------------------------------------------------------------------
  // The wallpaper player
  // ---------------------------------------------------------------------------

  /// Creates the background player on first real video use.
  ///
  /// The live player's platform configuration is used on purpose: media_kit's
  /// default attaches an Android surface before the video parameters are known,
  /// which renders video wallpapers black or as a single pixel.
  void _ensureVideoPlayer() {
    if (_videoPlayer != null) return;
    MediaKitPlayerAdapter.ensureInitialized();
    final player = Player();
    _videoPlayer = player;
    videoController.value = VideoController(player, configuration: wallpaperVideoControllerConfiguration());
    player.setVolume(0.0);
    player.setPlaylistMode(PlaylistMode.loop);

    _wallpaperDiagSubs
      ..clear()
      ..add(
        player.stream.error.listen((error) {
          log('[BGDIAG] wallpaper video error: $error', name: 'BackgroundController');
        }),
      )
      ..add(
        player.stream.videoParams.listen((params) {
          final int width = params.w ?? 0;
          final int height = params.h ?? 0;
          if (_wallpaperReadyLogged || width <= 0 || height <= 0) return;
          _wallpaperReadyLogged = true;
          log('[BGDIAG] wallpaper video decoded: $width x $height', name: 'BackgroundController');
        }),
      );
    _wallpaperReadyLogged = false;
  }

  bool get _hasVideoPlayer => _videoPlayer != null;

  /// Whether live playback currently holds the decoder.
  bool get isPlaybackSuspended => _playbackSuspended;
  bool _playbackSuspended = false;

  /// Hands the decoder to the live player while a stream is running.
  ///
  /// Two video layers decoding at once fight for the Android surface and the
  /// hardware decoder, so this does not merely pause the wallpaper: it captures
  /// the current frame as a poster and releases the player entirely. Only the
  /// static frame is drawn until playback lets go. If the capture is unsupported
  /// (some hwdec combinations), fall back to pausing on the last frame, which
  /// still avoids running two decoders.
  Future<void> setPlaybackActive(bool active) async {
    if (_playbackSuspended == active) return;
    _playbackSuspended = active;

    if (active) {
      if (!state.isVideo || !_hasVideoPlayer) return;
      final player = _videoPlayer;
      if (player == null) return;
      Uint8List? frame;
      try {
        frame = await player.screenshot(format: 'image/jpeg');
      } catch (_) {
        frame = null;
      }
      // The capture is asynchronous and playback can have ended while it was in
      // flight; that branch already rebuilt the background player, so acting on
      // a stale frame here would dispose the fresh one.
      if (!_playbackSuspended) return;
      if (frame != null && frame.isNotEmpty) {
        posterFrame.value = frame;
        _releaseVideoPlayer();
      } else {
        await player.pause();
      }
      return;
    }

    // Playback ended: drop the poster first - the background may have been
    // switched meanwhile, and a stale frame would show the wrong picture.
    if (posterFrame.value != null) posterFrame.value = null;
    if (state.isVideo) await reloadBackgroundVideo();
  }

  void _releaseVideoPlayer() {
    final player = _videoPlayer;
    _videoPlayer = null;
    videoController.value = null;
    for (final sub in _wallpaperDiagSubs) {
      unawaited(sub.cancel());
    }
    _wallpaperDiagSubs.clear();
    unawaited(player?.dispose());
  }

  /// Opens (or releases) the wallpaper clip to match [state].
  ///
  /// Also driven from the playback hand-back path, so it reads [state] rather
  /// than relying on a caller-provided configuration.
  Future<void> reloadBackgroundVideo() async {
    final source = switch (state.source) {
      BackgroundSource.video => state.videoPath,
      BackgroundSource.networkVideo => state.videoUrl,
      _ => '',
    };
    if (source.isEmpty) {
      // Not a video wallpaper: never keep an idle decoder around.
      _releaseVideoPlayer();
      return;
    }
    // While the live player is running the background shows the poster; the
    // video resumes when playback lets go (see [setPlaybackActive]).
    if (_playbackSuspended) return;

    final created = !_hasVideoPlayer;
    _ensureVideoPlayer();
    if (created) {
      // The player is lazy and the layer may have rendered while it did not
      // exist; publishing the controller is what makes it paint.
      videoController.refresh();
    }
    // A direct stream needs the browser-like headers the downloader used, or
    // the CDN answers 403 and no frame is ever produced.
    final headers = state.source == BackgroundSource.networkVideo ? wallpaperVideoHttpHeaders() : null;
    await _videoPlayer?.open(Media(source, httpHeaders: headers), play: !_playbackSuspended);
  }

  /// The image the background layer paints for the current configuration.
  ///
  /// A file the user picked or we downloaded resolves to a [FileImage]; a remote
  /// picture streams through the shared on-disk cache. Null means the caller
  /// should fall back to the themed surface.
  ImageProvider? get imageProvider {
    switch (state.source) {
      case BackgroundSource.image:
        if (state.imagePath.isEmpty || !File(state.imagePath).existsSync()) return null;
        return FileImage(File(state.imagePath));
      case BackgroundSource.networkImage:
        if (state.imageUrl.isEmpty) return null;
        return CachedNetworkImageProvider(state.imageUrl, cacheManager: AppImageCacheManager.instance);
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Backup / restore
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => <String, dynamic>{configKey: state.toJson()};

  /// Recognised keys with normalized values, so the backup ledger can validate
  /// the section without a running controller.
  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    return <String, dynamic>{configKey: _sectionOf(rootConfig).toJson()};
  }

  /// Normalizes a backup section. Pure: applying it is [fromJson]'s job.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return <String, dynamic>{configKey: _sectionOf(json).toJson()};
  }

  void fromJson(Map<String, dynamic> json) => _apply(_sectionOf(json));

  /// Reads the nested section, or the flat one when a legacy backup stored the
  /// fields at the top level.
  static BackgroundConfig _sectionOf(Map<String, dynamic>? json) {
    final section = json?[configKey];
    if (section is Map) return BackgroundConfig.fromJson(Map<String, dynamic>.from(section));
    return BackgroundConfig.fromJson(json ?? const <String, dynamic>{});
  }
}
