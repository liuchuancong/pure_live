import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/shared/player/player_teardown.dart' show silencePlayer;

/// What a cover preview plays: the resolved source and, when the address
/// needs returning (a loopback decrypt relay's entry, say), the call that
/// retires it once the preview is gone.
typedef CoverPreviewSource = ({PlayerSource source, void Function()? onDone});

/// A card cover's hover preview: opens [resolve]'s source on the app's
/// preview kernel, muted from before its first frame, and releases the
/// player the moment it leaves the tree.
///
/// The kernel is the previews' own ([previewKernelProvider]), so a hover
/// never joins the system media session and never contends with the player
/// the viewer is about to open. A resolve that answers nothing — or throws —
/// leaves the cover alone: the preview is a glance, never a verdict.
final class CoverPreviewPlayer extends ConsumerStatefulWidget {
  /// Plays [resolve]'s source for as long as this widget is mounted.
  const CoverPreviewPlayer({required this.resolve, this.viaPlayerProxy = true, super.key});

  /// Resolves the source to play. Null (or a throw) means "nothing to show".
  final Future<CoverPreviewSource?> Function() resolve;

  /// Whether the player rides the app's playback proxy, like a room's own
  /// playback does. A loopback source (a local decrypt relay) must not.
  final bool viaPlayerProxy;

  @override
  ConsumerState<CoverPreviewPlayer> createState() => _CoverPreviewPlayerState();
}

final class _CoverPreviewPlayerState extends ConsumerState<CoverPreviewPlayer> {
  PlayerHandle? _handle;
  PlayerKernel? _kernel;
  void Function()? _retire;
  int _epoch = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    _epoch++;
    final handle = _handle;
    _handle = null;
    final kernel = _kernel;
    _kernel = null;
    final retire = _retire;
    _retire = null;
    if (handle != null && kernel != null) {
      // Silent before queued behind the release: the pointer is already on
      // the next thing while this one drains.
      silencePlayer(handle);
      unawaited(_release(kernel, handle));
    }
    retire?.call();
    super.dispose();
  }

  static Future<void> _release(PlayerKernel kernel, PlayerHandle handle) async {
    try {
      await kernel.release(handle.id);
    } on Object {
      // The kernel or the engine is already gone; nothing is left to do.
    }
  }

  Future<void> _open() async {
    final epoch = ++_epoch;
    CoverPreviewSource? answer;
    try {
      answer = await widget.resolve();
    } on Object {
      answer = null;
    }
    if (!mounted || epoch != _epoch) {
      answer?.onDone?.call();
      return;
    }
    if (answer == null) {
      setState(() => _failed = true);
      return;
    }
    final kernel = ref.read(previewKernelProvider);
    _kernel = kernel;
    final PlayerHandle handle;
    try {
      handle = await kernel.create(
        config: const PlayerConfig(
          name: 'preview',
          autoPlay: true,
          muted: true,
          volume: 0,
          enableAudio: false,
          enableRecovery: false,
          pauseWhenBackgrounded: false,
        ),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
      if (!mounted || epoch != _epoch) {
        silencePlayer(handle);
        unawaited(_release(kernel, handle));
        answer.onDone?.call();
        return;
      }
      await handle.applyEngineOptions(
        playerStoredEngineOptions(
          hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
          tuning: ref.read(playerTuningProvider),
          proxy: widget.viaPlayerProxy ? ref.read(playerProxyProvider) : null,
        ),
      );
      await handle.open(answer.source, autoPlay: true);
    } on Object {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
      answer.onDone?.call();
      return;
    }
    _handle = handle;
    _retire = answer.onDone;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (handle == null) {
      // Resolving: the cover stays under a small spinner. A source that
      // could not be played leaves the cover alone.
      return _failed
          ? const SizedBox.shrink()
          : const Center(child: IgnorePointer(child: DsSpinner(style: DsSpinnerStyle(size: 20))));
    }
    // The card's tap opens the content: the preview is a picture only,
    // never a pointer's stop.
    return IgnorePointer(
      child: MediaPlayerView(
        handle: handle,
        fit: BoxFit.cover,
        backgroundColor: const Color(0x00000000),
        captureBoundary: false,
      ),
    );
  }
}
