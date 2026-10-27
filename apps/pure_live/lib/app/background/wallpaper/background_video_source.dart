import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart'
    show
        KernelOptions,
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
import 'package:pure_uikit_background/pure_uikit_background.dart' show BackgroundVideoSource;

/// The app's [BackgroundVideoSource] over media_core.
///
/// It owns a small kernel of its own: no audio driver (the wallpaper is
/// muted and must not touch the media session), no pool and no presentation
/// driver. Pausing keeps the last frame, so a room opening over the shell
/// does not leave a black rectangle when it closes.
final class AppBackgroundVideoSource implements BackgroundVideoSource {
  /// Loops [uri] behind the pages; a local `file:` URI or an http(s) URL.
  const AppBackgroundVideoSource(this.uri);

  /// The media to paint.
  final Uri uri;

  @override
  Widget buildView({
    required bool paused,
    required bool looping,
    required bool muted,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) => _BackgroundVideoView(
    // A new source means a new decoder; pause/fit changes keep the same one.
    key: ValueKey(uri.toString()),
    uri: uri,
    paused: paused,
    looping: looping,
    muted: muted,
    fit: fit,
    alignment: alignment,
  );
}

final class _BackgroundVideoView extends StatefulWidget {
  const _BackgroundVideoView({
    required this.uri,
    required this.paused,
    required this.looping,
    required this.muted,
    required this.fit,
    required this.alignment,
    super.key,
  });

  final Uri uri;
  final bool paused;
  final bool looping;
  final bool muted;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  State<_BackgroundVideoView> createState() => _BackgroundVideoViewState();
}

final class _BackgroundVideoViewState extends State<_BackgroundVideoView> {
  PlayerKernel? _kernel;
  PlayerHandle? _handle;
  bool _disposed = false;

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
      if (handle != null) unawaited(widget.paused ? handle.pause() : handle.play());
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

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (handle == null) return const SizedBox.expand();
    return MediaPlayerView(
      handle: handle,
      fit: widget.fit,
      alignment: widget.alignment,
      backgroundColor: const Color(0x00000000),
      captureBoundary: false,
    );
  }
}
