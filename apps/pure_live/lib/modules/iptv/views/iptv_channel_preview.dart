import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel;
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_user_agent.dart'
    show iptvHeadersWithUserAgent, iptvUserAgentProvider;

/// A channel row's hover preview: resting on the row half a second floats a
/// small window beside it playing the channel itself, muted, and leaving the
/// row takes it back. The browser is a table of names — there is no cover to
/// play on — so the glance hangs off the row instead.
final class IptvChannelHoverPreview extends StatefulWidget {
  /// Floats [channel]'s stream beside [child] while the pointer rests.
  const IptvChannelHoverPreview({required this.channel, required this.child, super.key});

  /// The channel whose stream plays.
  final IptvChannel channel;

  /// The row content the preview hangs from.
  final Widget child;

  @override
  State<IptvChannelHoverPreview> createState() => _IptvChannelHoverPreviewState();
}

class _IptvChannelHoverPreviewState extends State<IptvChannelHoverPreview> {
  final DsOverlayController _controller = DsOverlayController();

  /// The dwell between arriving and floating: a walk down the table must not
  /// open a stream under every row the pointer crosses.
  static const Duration _dwellBefore = Duration(milliseconds: 500);

  Timer? _dwell;
  bool _pointerInside = false;

  void _enter() {
    _pointerInside = true;
    _dwell ??= Timer(_dwellBefore, () {
      _dwell = null;
      if (_pointerInside && mounted) _controller.open();
    });
  }

  void _exit() {
    _pointerInside = false;
    _dwell?.cancel();
    _dwell = null;
    if (_controller.isOpen) _controller.close();
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DsPopover(
      controller: _controller,
      side: DsSide.end,
      contentBuilder: (context) => SizedBox(
        width: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DsTheme.of(context).radii.card),
          child: AspectRatio(aspectRatio: 16 / 9, child: IptvChannelPreviewVideo(channel: widget.channel)),
        ),
      ),
      child: MouseRegion(onEnter: (_) => _enter(), onExit: (_) => _exit(), child: widget.child),
    );
  }
}

/// The floating window's inside: the channel's own stream, played muted on
/// the app's preview kernel for as long as this widget is mounted. The
/// playlist line's addresses play directly — no plan to resolve — so the
/// lines travel together and the sweep walks them on a dead one, exactly as
/// the channel's own player does.
final class IptvChannelPreviewVideo extends ConsumerStatefulWidget {
  /// Plays [channel] muted.
  const IptvChannelPreviewVideo({required this.channel, super.key});

  /// The channel whose stream plays.
  final IptvChannel channel;

  @override
  ConsumerState<IptvChannelPreviewVideo> createState() => _IptvChannelPreviewVideoState();
}

final class _IptvChannelPreviewVideoState extends ConsumerState<IptvChannelPreviewVideo> {
  LivePlaybackController? _playback;
  PlayerHandle? _handle;
  StreamSubscription<PlayerHandle>? _handles;
  StreamSubscription<PlayerFailure>? _errors;
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
    unawaited(_handles?.cancel() ?? Future<void>.value());
    _handles = null;
    unawaited(_errors?.cancel() ?? Future<void>.value());
    _errors = null;
    final playback = _playback;
    _playback = null;
    unawaited(playback?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _open() async {
    final epoch = ++_epoch;
    final channel = widget.channel;
    final urls = <String>[
      if (channel.entry.url.trim().isNotEmpty) channel.entry.url.trim(),
      for (final alternative in channel.entry.alternatives)
        if (alternative.trim().isNotEmpty) alternative.trim(),
    ];
    if (urls.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    // The playlist line's own User-Agent wins; otherwise the viewer's custom
    // one is sent, matching what the channel's own player sends.
    final playbackHeaders = iptvHeadersWithUserAgent(channel.entry.headers.asMap(), ref.read(iptvUserAgentProvider));
    final headers = playbackHeaders.isEmpty ? null : SourceHeaders(playbackHeaders);
    final sources = [
      for (final (index, url) in urls.indexed)
        PlayerSource.of(
          id: SourceId('iptv-preview:${channel.id}:$index'),
          uri: Uri.parse(url),
          type: SourceType.live,
          protocol: SourceProtocol.fromScheme(Uri.parse(url).scheme),
          format: SourceFormat.fromUri(Uri.parse(url)),
          headers: headers,
          title: channel.entry.name,
        ),
    ];
    final playback = _playback ??= LivePlaybackController(ref.read(previewKernelProvider));
    _errors = playback.onError.listen((_) {
      if (!mounted || epoch != _epoch) return;
      if (_handle == null) setState(() => _failed = true);
    });
    _handles = playback.onHandleChanged.listen((handle) {
      if (!mounted || epoch != _epoch || handle.disposed) return;
      // Muted before the open below lets a frame play: the preview never
      // speaks, whatever the channel carries.
      unawaited(handle.setVolume(0));
      unawaited(handle.setMute(muted: true));
      if (mounted) setState(() => _handle = handle);
    });
    try {
      await playback.play(
        LiveSourceRequest(
          sources: sources,
          title: channel.entry.name,
          allowEngineFallback: true,
          engineOptions: playerStoredEngineOptions(
            hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
            tuning: ref.read(playerTuningProvider),
            proxy: ref.read(playerProxyProvider),
          ),
        ),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
    } on Object {
      if (!mounted || epoch != _epoch) return;
      if (_handle == null) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (handle == null) {
      return _failed
          ? const SizedBox.shrink()
          : const Center(child: IgnorePointer(child: DsSpinner(style: DsSpinnerStyle(size: 20))));
    }
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
