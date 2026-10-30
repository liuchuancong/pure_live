import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart'
    show
        KernelOptions,
        MediaPlayerView,
        PlayerConfig,
        PlayerHandle,
        PlayerHandleLifecycle,
        PlayerHandlePlayback,
        PlayerKernel,
        PlayerScreenshot,
        PlayerSource,
        ScreenshotFormat,
        ScreenshotOptions,
        SourceFormat,
        SourceId,
        SourceProtocol,
        SourceType;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitAdapterFactory;
import 'package:pure_live/app/background/tone/background_frames.dart' show backgroundVideoFrameProvider;
import 'package:pure_live/app/background/tone/background_thumbnails.dart' show backgroundClipStillsProvider;
import 'package:pure_uikit_background/pure_uikit_background.dart' show BackgroundVideoSource;

/// The position the live tone probe waits for: far enough in that a frame has
/// been decoded and handed to the video output.
const Duration _kTonePosition = Duration(milliseconds: 400);

/// How long a failed live capture waits before trying again.
const Duration _kToneRetry = Duration(milliseconds: 500);

/// The app's [BackgroundVideoSource] over media_core.
///
/// It owns a small kernel of its own: no audio driver (the wallpaper is
/// muted and must not touch the media session), no pool and no presentation
/// driver. Pausing keeps the last frame, so a room opening over the shell
/// does not leave a black rectangle when it closes.
///
/// The frost ([blurSigma]) is applied inside the decoder's own state: the
/// desen background paints its blur above the source, and a blur that comes
/// and goes would change the tree there and restart the clip. Below the
/// decoder only the view is remounted, which rebinds the same texture.
final class AppBackgroundVideoSource implements BackgroundVideoSource {
  /// Loops [uri] behind the pages; a local `file:` URI or an http(s) URL.
  const AppBackgroundVideoSource(this.uri, {this.blurSigma = 0});

  /// The media to paint.
  final Uri uri;

  /// Gaussian sigma of the frost over the decoded frame; 0 keeps it sharp.
  final double blurSigma;

  @override
  Widget buildView({
    required bool paused,
    required bool looping,
    required bool muted,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) => _BackgroundVideoView(
    // A new source means a new decoder; pause/fit/blur changes keep the same one.
    key: ValueKey(uri.toString()),
    uri: uri,
    paused: paused,
    looping: looping,
    muted: muted,
    fit: fit,
    alignment: alignment,
    blurSigma: blurSigma,
  );
}

final class _BackgroundVideoView extends ConsumerStatefulWidget {
  const _BackgroundVideoView({
    required this.uri,
    required this.paused,
    required this.looping,
    required this.muted,
    required this.fit,
    required this.alignment,
    required this.blurSigma,
    super.key,
  });

  final Uri uri;
  final bool paused;
  final bool looping;
  final bool muted;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double blurSigma;

  @override
  ConsumerState<_BackgroundVideoView> createState() => _BackgroundVideoViewState();
}

final class _BackgroundVideoViewState extends ConsumerState<_BackgroundVideoView> {
  PlayerKernel? _kernel;
  PlayerHandle? _handle;
  bool _disposed = false;
  bool _tonePublished = false;
  bool _toneProbing = false;
  bool _toneRequested = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void didUpdateWidget(_BackgroundVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) {
      final handle = _handle;
      if (handle != null) {
        unawaited(widget.paused ? handle.pause() : handle.play());
        if (!widget.paused) unawaited(_publishTone(handle));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final kernel = _kernel;
    final handle = _handle;
    _kernel = null;
    _handle = null;
    if (kernel != null && handle != null) {
      unawaited(_release(kernel, handle));
    }
    // With no handle yet, _start's own completion releases the kernel.
    super.dispose();
  }

  Future<void> _release(PlayerKernel kernel, PlayerHandle handle) async {
    try {
      await kernel.release(handle.id);
    } on Object {
      // Already gone; the dispose below still tears the kernel down.
    }
    try {
      await kernel.dispose();
    } on Object {
      // A shutdown that is already running wins; nothing is left to do.
    }
  }

  Future<void> _start() async {
    final kernel = PlayerKernel(
      options: const KernelOptions(
        autoAttachAudio: false,
        enablePool: false,
        // A wallpaper that fails on a bad URL has nothing to recover; the
        // caller's underlay is the honest surface.
        enableRecovery: false,
      ),
    )..registerBackend(const MediaKitAdapterFactory().registration());
    _kernel = kernel;
    try {
      final handle = await kernel.create(
        config: PlayerConfig(
          name: 'background',
          autoPlay: !widget.paused,
          loop: widget.looping,
          muted: widget.muted,
          volume: 0,
          enableAudio: false,
          pauseWhenBackgrounded: true,
          enableRecovery: false,
        ),
        source: _sourceOf(widget.uri),
      );
      if (_disposed) {
        await _release(kernel, handle);
        return;
      }
      _handle = handle;
      if (widget.paused) {
        await handle.pause();
      }
      if (mounted) {
        setState(() {});
      }
      unawaited(_publishTone(handle));
    } on Object {
      if (!_disposed) {
        if (mounted) {
          setState(() {
            _kernel = null;
          });
        }
      }
      try {
        await kernel.dispose();
      } on Object {
        // Nothing left to release.
      }
    }
  }

  PlayerSource _sourceOf(Uri uri) {
    final type = uri.scheme == 'file' ? SourceType.file : SourceType.remote;
    return PlayerSource.of(
      id: SourceId('background:${uri.toString().hashCode}'),
      uri: uri,
      type: type,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: SourceFormat.fromUri(uri),
      title: 'background',
    );
  }

  /// Hands one decoded frame to the tone reader, so the pages can pick their
  /// ink from what the clip actually shows.
  ///
  /// The headless still is the reliable sample and the tone reader already
  /// prefers it, so once it exists this live probe has nothing to add. Only
  /// when no still could be taken does it capture the playing frame; a paused
  /// player has no new frame to offer and is left alone until it resumes.
  Future<void> _publishTone(PlayerHandle handle) async {
    if (_tonePublished) return;
    if (_toneProbing) {
      _toneRequested = true;
      return;
    }
    _toneProbing = true;
    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        if (_disposed || !mounted) return;
        if (_stillExists) {
          _tonePublished = true;
          return;
        }
        if (widget.paused) return;
        try {
          await handle.stateChanges
              .firstWhere((state) => state.position >= _kTonePosition)
              .timeout(const Duration(seconds: 2));
        } on Object {
          // Nothing moved yet; the position below decides whether there is a
          // frame worth asking for.
        }
        if (_disposed || !mounted || widget.paused) return;
        if (handle.playback.position < _kTonePosition) {
          // The clip has not reached a decoded frame. Capturing now would ask
          // the surface for whatever is behind the pages, which is not the
          // picture the tone is supposed to read.
          await Future<void>.delayed(_kToneRetry);
          continue;
        }
        if (_stillExists) {
          _tonePublished = true;
          return;
        }
        PlayerScreenshot? screenshot;
        try {
          screenshot = await handle.captureScreenshot(
            // The live wallpaper is on screen, so a failed engine capture can
            // fall back to the rendered surface: the picture the viewer sees
            // is there even when mpv will not hand a frame back. A tone probe
            // needs no more than a small picture, hence the low pixel ratio.
            options: const ScreenshotOptions(
              format: ScreenshotFormat.jpeg,
              quality: 40,
              pixelRatio: 0.25,
              timeout: Duration(seconds: 2),
            ),
          );
        } on Object {
          // A handle torn down mid-probe (or an engine that cannot capture)
          // answers nothing; an unknown tone keeps the viewer's brightness.
          return;
        }
        final bytes = screenshot?.bytes;
        if (bytes != null) {
          ref.read(backgroundVideoFrameProvider.notifier).publish(widget.uri.toString(), bytes);
          // The frame on screen is a truthful still; keep it so the next run
          // and the download rows have one even when a headless capture
          // cannot produce it.
          unawaited(ref.read(backgroundClipStillsProvider).remember(widget.uri.toString(), bytes));
          _tonePublished = true;
          return;
        }
        // The first frame may still be on its way; give the decoder a moment
        // instead of burning all four attempts in a single synchronous burst.
        await Future<void>.delayed(_kToneRetry);
      }
    } finally {
      _toneProbing = false;
      if (_toneRequested) {
        _toneRequested = false;
        if (!_disposed && mounted && !widget.paused && !_tonePublished) unawaited(_publishTone(handle));
      }
    }
  }

  /// Whether the headless still for this clip is already on disk.
  bool get _stillExists => ref.read(backgroundClipStillsProvider).stored(widget.uri.toString()) != null;

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (handle == null) return const SizedBox.expand();
    // The tone probe reads the rendered frame, so the view keeps its capture
    // boundary; one extra layer behind the pages is cheap.
    final view = MediaPlayerView(
      handle: handle,
      fit: widget.fit,
      alignment: widget.alignment,
      backgroundColor: const Color(0x00000000),
    );
    if (widget.blurSigma <= 0) return view;
    return ImageFiltered(
      // Decal keeps the frost from stretching the edge pixels; the decoder
      // stays where it is because this wrapper lives under its state.
      imageFilter: ui.ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma, tileMode: ui.TileMode.decal),
      child: view,
    );
  }
}
