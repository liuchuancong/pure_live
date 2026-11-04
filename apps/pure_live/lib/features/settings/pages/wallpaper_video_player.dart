import 'dart:async' show StreamSubscription, Timer, unawaited;
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
    show SettingsPreviewCircleButton, SettingsPreviewTransportBar;
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
    this.loop = true,
    this.onHandle,
    this.barLeading = const [],
    this.barActions = const [],
    this.barHideAfter,
    super.key,
  });

  /// The clip to play; a local `file:` URI or an http(s) URL.
  final Uri uri;

  /// Whether the clip starts over at its end. A wallpaper loops for as long
  /// as the app runs; a preview of one recording stops on its last frame.
  final bool loop;

  /// Told the handle the clip opened on, so a host can put another timeline
  /// (the danmaku layer) on the picture's own clock. A retry reports the
  /// handle it builds next.
  final ValueChanged<PlayerHandle>? onHandle;

  /// The host page's verbs at the bar's start, before play: a preview's
  /// 上一项/下一项 sit where a player puts them.
  final List<Widget> barLeading;

  /// The host page's own verbs, appended after the transport in the bar's row.
  /// One bar over the picture is what a preview reads as — the alternative is
  /// a second floating strip the viewer has to learn separately.
  final List<Widget> barActions;

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

  /// How long the transport bar waits before settling away while the clip
  /// plays; null keeps it up.
  ///
  /// A settings preview the viewer is adjusting wants its controls on screen,
  /// so it passes nothing. A full-page player hands the app's own 画面与浮窗
  /// delay: a bar that never leaves covers the picture the viewer came to look
  /// at, and every other surface in the app already hides on this clock.
  final Duration? barHideAfter;

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

  /// Whether the transport bar is up. A pointer over the picture or the bar
  /// holds it; a playing clip lets it settle away on the host's own clock, and
  /// a paused one keeps it — the rule every other player in the app follows.
  bool _barVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  /// Puts the bar back up and restarts its countdown.
  void _wakeBar() {
    if (widget.barHideAfter == null) return;
    if (!_barVisible) setState(() => _barVisible = true);
    _scheduleHideBar();
  }

  void _scheduleHideBar() {
    _hideTimer?.cancel();
    final after = widget.barHideAfter;
    if (after == null || !_playing) return;
    _hideTimer = Timer(after, () {
      if (mounted && _playing) setState(() => _barVisible = false);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
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
    // The release below is queued behind whatever the preview is still doing;
    // mute first — it lands at once — then pause, so the wallpaper cannot be
    // heard over the pane the viewer returned to while that queue drains.
    // Both are fire-and-forget; a handle already being released is silent by
    // definition, so a refusal needs no answer.
    unawaited(() async {
      try {
        await handle.setMute(muted: true);
      } on Object {
        // Already gone.
      }
      try {
        await handle.pause();
      } on Object {
        // Already gone.
      }
    }());
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
          loop: widget.loop,
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
      widget.onHandle?.call(handle);
      _states = handle.stateChanges.listen((state) {
        if (!mounted) return;
        final wasPlaying = _playing;
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
        // A clip that starts playing earns its hiding; one that stopped keeps
        // the bar, so the play button is where the viewer left it.
        if (_playing && !wasPlaying) _scheduleHideBar();
        if (!_playing) _hideTimer?.cancel();
      });
    } on Object {
      // The kernel never got a handle, so dispose's own teardown skips it —
      // _start owns the failed kernel either way, or a retry would pile
      // half-built decoders up one per press.
      try {
        await kernel.dispose();
      } on Object {
        // A shutdown that is already running wins; nothing is left to do.
      }
      if (mounted) setState(() => _kernel = null);
    }
  }

  Future<void> _toggle() async {
    // A press always puts the bar back up: on a touch screen there is no hover
    // to do it, and the viewer just asked the picture to change state.
    _wakeBar();
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
      // A decoder that could not start: the honest surface over a black
      // box, with the one verb the failure leaves — try again.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s8,
          children: [
            DsIcon(DsIcons.videoOff, size: 28, color: colors.textSubtle),
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(_start()),
              child: Text(t.common.retry),
            ),
          ],
        ),
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
          child: MouseRegion(
            onHover: (_) => _wakeBar(),
            onExit: (_) => _scheduleHideBar(),
            child: DsPressable(
              semanticLabel: _playing ? t.room.pause : t.room.play,
              onPressed: () => unawaited(_toggle()),
              builder: (context, states, _) => const SizedBox.expand(),
            ),
          ),
        ),
        if (!_playing && !_buffering) const Center(child: DsIcon(DsIcons.play, size: 44, color: Color(0xCCFFFFFF))),
        if (_buffering)
          const Center(
            child: DsSpinner(style: DsSpinnerStyle(size: 32, color: Color(0xFFFFFFFF))),
          ),
        if (_barVisible || !_playing)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: MouseRegion(
              // Resting on the bar keeps it up; leaving settles it the way an
              // idle pointer does.
              onEnter: (_) => _hideTimer?.cancel(),
              onExit: (_) => _scheduleHideBar(),
              child: SettingsPreviewTransportBar(
                controls: [
                  ...widget.barLeading,
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
                  ...widget.barActions,
                ],
                transport: Row(
                  spacing: DsSpace.s4,
                  children: [
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
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
