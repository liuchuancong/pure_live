import 'dart:async' show StreamSubscription, unawaited;
import 'dart:ui' as ui;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart'
    show
        MediaPlayerView,
        PlayerConfig,
        PlayerHandle,
        PlayerHandlePlayback,
        PlayerKernel,
        PlayerSource,
        SourceFormat,
        SourceId,
        SourceProtocol,
        SourceType;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitAdapterFactory;
import 'package:pure_live/features/settings/surface/settings_preview.dart'
    show SettingsPreviewBar, SettingsPreviewCircleButton;
import 'package:pure_live/l10n/translations.dart';

/// The clip's own stage: the app's media_core player with the reference
/// viewer's transport under it — play/pause, a seekable bar with the
/// timecode, and mute. A new address means a new decoder; the transport's
/// own state (paused, muted) belongs to this widget alone.
final class WallpaperVideoPlayer extends StatefulWidget {
  const WallpaperVideoPlayer({
    required this.uri,
    this.overlay,
    this.fit = BoxFit.contain,
    this.blurSigma = 0,
    super.key,
  });

  /// The clip to play; a local `file:` URI or an http(s) URL.
  final Uri uri;

  /// Painted over the picture, under the transport: the preview's mask and
  /// frost, so the controls stay as legible as they are without it.
  final Widget? overlay;

  /// How the frame fills the stage — the display mode the preview panel
  /// chose, so the clip sits the way the wallpaper will.
  final BoxFit fit;

  /// Gaussian sigma of the frost over the decoded frame; 0 keeps it sharp.
  /// The app's own wallpaper source frosts the same way, so the preview
  /// shows the sigma the applied background will wear.
  final double blurSigma;

  @override
  State<WallpaperVideoPlayer> createState() => _WallpaperVideoPlayerState();
}

final class _WallpaperVideoPlayerState extends State<WallpaperVideoPlayer> {
  PlayerKernel? _kernel;
  PlayerHandle? _handle;
  StreamSubscription<Object>? _states;
  bool _disposed = false;
  bool _playing = false;
  bool _buffering = false;
  bool _muted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// A seek the viewer is dragging: the bar follows the finger, not the
  /// decoder, until the touch lets go.
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_states?.cancel() ?? Future<void>.value());
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
    final kernel = PlayerKernel()..registerBackend(const MediaKitAdapterFactory().registration());
    _kernel = kernel;
    try {
      final handle = await kernel.create(
        config: PlayerConfig(
          name: 'wallpaper-preview',
          autoPlay: true,
          loop: true,
          muted: _muted,
          pauseWhenBackgrounded: true,
          enableRecovery: false,
        ),
        source: PlayerSource.of(
          id: SourceId('wallpaper-preview:${widget.uri.toString().hashCode}'),
          uri: widget.uri,
          type: widget.uri.scheme == 'file' ? SourceType.file : SourceType.remote,
          protocol: SourceProtocol.fromScheme(widget.uri.scheme),
          format: SourceFormat.fromUri(widget.uri),
          title: 'wallpaper-preview',
        ),
      );
      if (_disposed) {
        await _release(kernel, handle);
        return;
      }
      _handle = handle;
      _states = handle.stateChanges.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing = state.isPlaying;
          _buffering = state.buffering;
          if (_dragValue == null) {
            _position = state.position;
            _duration = state.duration;
          } else {
            _duration = state.duration;
          }
        });
      });
    } on Object {
      if (_disposed) {
        try {
          await kernel.dispose();
        } on Object {
          // Nothing left to release.
        }
      } else if (mounted) {
        setState(() => _kernel = null);
      }
    }
  }

  Future<void> _toggle() async {
    final handle = _handle;
    if (handle == null) return;
    await (_playing ? handle.pause() : handle.play());
  }

  Future<void> _seekTo(double fraction) async {
    final handle = _handle;
    final duration = _duration;
    if (handle == null || duration <= Duration.zero) return;
    await handle.seek(duration * fraction.clamp(0.0, 1.0));
  }

  Future<void> _toggleMute() async {
    final handle = _handle;
    if (handle == null) return;
    setState(() => _muted = !_muted);
    await handle.setMute(muted: _muted);
  }

  /// The bar's value: the finger's own while it drags, the decoder's
  /// otherwise.
  double get _barValue {
    final drag = _dragValue;
    if (drag != null) return drag.clamp(0.0, 1.0);
    if (_duration <= Duration.zero) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  static String _clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final handle = _handle;
    final colors = DsTheme.colorsOf(context);
    if (handle == null && _kernel == null) {
      return Center(
        child: DsIcon(DsIcons.videoOff, size: 28, color: colors.textSubtle),
        // A decoder that could not start: the honest surface over a black box.
      );
    }
    if (handle == null) {
      return Center(
        child: DsSpinner(style: const DsSpinnerStyle(size: 28), semanticLabel: t.settings.backgroundVideo),
      );
    }
    final total = _duration;
    final picture = MediaPlayerView(handle: handle, fit: widget.fit);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.blurSigma <= 0)
          picture
        else
          ImageFiltered(
            // The same decal frost the applied wallpaper's source wears; it
            // sits under the state, so moving the slider never restarts the
            // clip.
            imageFilter: ui.ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
              tileMode: ui.TileMode.decal,
            ),
            child: picture,
          ),
        if (widget.overlay case final overlay?) Positioned.fill(child: IgnorePointer(child: overlay)),
        // Tap the picture itself to toggle, the way every clip player does;
        // the menu region above the stage keeps its own right click.
        Positioned.fill(
          child: DsPressable(
            semanticLabel: _playing ? t.room.pause : t.room.play,
            onPressed: () => unawaited(_toggle()),
            builder: (context, states, _) => const SizedBox.expand(),
          ),
        ),
        if (!_playing && !_buffering) const Center(child: DsIcon(DsIcons.play, size: 44, color: Color(0xCCFFFFFF))),
        if (_buffering)
          const Center(
            child: DsSpinner(style: DsSpinnerStyle(size: 32, color: Color(0xFFFFFFFF))),
          ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: SettingsPreviewBar(
            children: [
              SettingsPreviewCircleButton(
                icon: _playing ? DsIcons.pause : DsIcons.play,
                semanticLabel: _playing ? t.room.pause : t.room.play,
                onPressed: () => unawaited(_toggle()),
              ),
              SettingsPreviewCircleButton(
                icon: _muted ? DsIcons.volumeOff : DsIcons.volume,
                semanticLabel: _muted ? t.room.unmute : t.room.mute,
                onPressed: () => unawaited(_toggleMute()),
              ),
              const SizedBox(width: DsSpace.s4),
              SizedBox(
                width: 44,
                child: Text(
                  _clock(_dragValue == null ? _position : total * _barValue),
                  style: DsTheme.of(context).typography.caption.copyWith(color: const Color(0xCCFFFFFF)),
                ),
              ),
              Expanded(
                child: DsSlider(
                  value: _barValue,
                  semanticLabel: t.settings.backgroundVideo,
                  onChanged: total <= Duration.zero ? null : (value) => setState(() => _dragValue = value),
                  onChangeEnd: total <= Duration.zero
                      ? null
                      : (value) {
                          setState(() => _dragValue = null);
                          unawaited(_seekTo(value));
                        },
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  _clock(total),
                  textAlign: TextAlign.end,
                  style: DsTheme.of(context).typography.caption.copyWith(color: const Color(0xCCFFFFFF)),
                ),
              ),
              const SizedBox(width: DsSpace.s4),
            ],
          ),
        ),
      ],
    );
  }
}
